"""
Script to generate lemma definitions/descriptions for concepts using Gemini API in batches.
Retrieves concepts without descriptions and generates definitions for them.
If a term+PoS combination has multiple distinct meanings, creates duplicate records.
"""
import sys
import json
import logging
import time
from typing import List, Dict
from sqlmodel import Session, select
from app.core.database import engine
from app.models.models import Concept
from app.core.config import settings
import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Batch size for processing concepts
BATCH_SIZE = 20
# Delay between API calls (seconds) to avoid rate limits
API_DELAY = 1.0


def call_gemini_api(prompt: str) -> tuple[str, dict]:
    """
    Call Gemini API to generate definitions.
    
    Args:
        prompt: The prompt to send to the LLM
        
    Returns:
        Tuple of (generated text, token usage dict)
        
    Raises:
        Exception: If API call fails
    """
    api_key = settings.google_gemini_api_key
    if not api_key:
        raise Exception("Google Gemini API key not configured")
    
    model_name = "gemini-2.5-flash"
    base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
    
    payload = {
        "contents": [{
            "parts": [{
                "text": prompt
            }]
        }],
        "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 4096,
        }
    }
    
    try:
        response = requests.post(
            f"{base_url}?key={api_key}",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        response.raise_for_status()
        data = response.json()
        
        # Extract token usage
        usage_metadata = data.get('usageMetadata', {})
        prompt_tokens = usage_metadata.get('promptTokenCount', 0)
        output_tokens = usage_metadata.get('candidatesTokenCount', 0)
        total_tokens = usage_metadata.get('totalTokenCount', prompt_tokens + output_tokens)
        
        token_usage = {
            'prompt_tokens': prompt_tokens,
            'output_tokens': output_tokens,
            'total_tokens': total_tokens,
            'model_name': model_name
        }
        
        # Extract generated text
        if 'candidates' in data and len(data['candidates']) > 0:
            candidate = data['candidates'][0]
            if 'content' in candidate and 'parts' in candidate['content']:
                text = candidate['content']['parts'][0].get('text', '').strip()
                if not text:
                    raise Exception("LLM returned empty response")
                return text, token_usage
            else:
                raise Exception("LLM response missing content or parts")
        else:
            raise Exception("LLM response missing candidates")
            
    except requests.exceptions.RequestException as e:
        error_msg = f"Gemini API request failed: {str(e)}"
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                error_msg += f" - {error_data}"
            except:
                error_msg += f" - Status: {e.response.status_code}"
        logger.error(error_msg)
        raise Exception(error_msg)


def parse_definitions_from_response(response_text: str) -> List[str]:
    """
    Parse definitions from LLM response.
    The LLM should return a JSON array of definitions, or a structured format.
    
    Args:
        response_text: The raw text response from the LLM
        
    Returns:
        List of definition strings
    """
    # Try to extract JSON from markdown code blocks
    text = response_text.strip()
    if text.startswith('```'):
        lines = text.split('\n')
        if lines[0].startswith('```'):
            text = '\n'.join(lines[1:-1]) if len(lines) > 2 else text
        if text.endswith('```'):
            text = text[:-3]
    
    # Try to parse as JSON
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return [str(d) for d in data if d]
        elif isinstance(data, dict):
            # Check for common keys
            if 'definitions' in data:
                return [str(d) for d in data['definitions'] if d]
            elif 'descriptions' in data:
                return [str(d) for d in data['descriptions'] if d]
            else:
                # Return all string values
                return [str(v) for v in data.values() if v]
    except json.JSONDecodeError:
        pass
    
    # If not JSON, try to parse as numbered list or bullet points
    definitions = []
    lines = text.split('\n')
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # Remove numbering or bullets
        line = line.lstrip('0123456789.-) ')
        if line and len(line) > 10:  # Minimum reasonable definition length
            definitions.append(line)
    
    # If we got multiple definitions, return them
    if len(definitions) > 1:
        return definitions
    
    # Otherwise, return the whole text as a single definition
    if text:
        return [text]
    
    return []


def generate_definitions_batch(concepts: List[Concept]) -> Dict[int, List[str]]:
    """
    Generate definitions for a batch of concepts using Gemini API.
    
    Args:
        concepts: List of Concept objects to generate definitions for
        
    Returns:
        Dictionary mapping concept_id -> list of definitions
    """
    if not concepts:
        return {}
    
    # Build the prompt
    concept_list = []
    for concept in concepts:
        pos_str = f" ({concept.part_of_speech})" if concept.part_of_speech else ""
        concept_list.append(f"- {concept.term}{pos_str}")
    
    concepts_text = "\n".join(concept_list)
    
    prompt = f"""You are a language learning assistant. Generate concise, educational definitions/descriptions for the following English words and their parts of speech.

For each word, provide a clear definition that helps language learners understand the meaning. The definition should be:
- Concise (1-2 sentences for simple words, 2-3 sentences for complex concepts)
- Educational and suitable for language learning
- Clear and informative
- Written in English

CRITICAL: If a word+part-of-speech combination has MULTIPLE DISTINCT meanings (not just slight variations or related uses), provide 2 or more separate definitions as an array. Only provide multiple definitions if the meanings are truly distinct and different. Examples:
- "bank (noun)" could have: ["A financial institution where people deposit money", "The land alongside a river or lake"]
- "bark (noun)" could have: ["The outer covering of a tree", "The sound a dog makes"]
- Do NOT provide multiple definitions for minor variations, different contexts of the same meaning, or related uses.

Return your response as a JSON object where each key is the word followed by the part of speech in parentheses (e.g., "word (noun)"), and the value is either:
- A single string for one definition (DEFAULT - use this in most of cases), OR
- An array of strings ONLY for true homonyms with unrelated meanings

Example format:
{{
  "conservative (adjective)": "Holding traditional values and being resistant to change",
  "bank (noun)": ["A financial institution where people deposit and withdraw money", "The land alongside a river, lake, or other body of water"],
  "run (verb)": ["To move quickly on foot", "To operate or manage something"]
}}

Words to define:
{concepts_text}

Return only valid JSON, no markdown formatting, no code blocks, no additional text. Start with {{ and end with }}."""

    logger.info("Calling Gemini API for batch of %d concepts...", len(concepts))
    
    try:
        response_text, token_usage = call_gemini_api(prompt)
        logger.info("API call completed. Tokens: %d", token_usage['total_tokens'])
        
        # Parse the response
        definitions_map = {}
        
        # Try to parse as JSON
        text = response_text.strip()
        if text.startswith('```'):
            lines = text.split('\n')
            if lines[0].startswith('```'):
                text = '\n'.join(lines[1:-1]) if len(lines) > 2 else text
            if text.endswith('```'):
                text = text[:-3]
        
        try:
            response_data = json.loads(text)
            
            # Map the response back to concepts
            for concept in concepts:
                pos_str = f" ({concept.part_of_speech})" if concept.part_of_speech else ""
                key = f"{concept.term}{pos_str}"
                
                definitions = []
                
                # Try exact match first (word + PoS)
                if key in response_data:
                    value = response_data[key]
                    if isinstance(value, list):
                        definitions = [str(d).strip() for d in value if d and str(d).strip()]
                    else:
                        if value and str(value).strip():
                            definitions = [str(value).strip()]
                else:
                    # Try with lowercase key
                    key_lower = key.lower()
                    for resp_key, resp_value in response_data.items():
                        if resp_key.lower() == key_lower:
                            if isinstance(resp_value, list):
                                definitions = [str(d).strip() for d in resp_value if d and str(d).strip()]
                            else:
                                if resp_value and str(resp_value).strip():
                                    definitions = [str(resp_value).strip()]
                            break
                    
                    # If still not found, try without PoS
                    if not definitions and concept.term in response_data:
                        value = response_data[concept.term]
                        if isinstance(value, list):
                            definitions = [str(d).strip() for d in value if d and str(d).strip()]
                        else:
                            if value and str(value).strip():
                                definitions = [str(value).strip()]
                
                if definitions:
                    definitions_map[concept.id] = definitions
                    logger.info("Found %d definition(s) for concept %d (%s%s)", len(definitions), concept.id, concept.term, pos_str)
                else:
                    logger.warning("No definition found in response for concept %d (%s%s)", concept.id, concept.term, pos_str)
                    definitions_map[concept.id] = []
        
        except json.JSONDecodeError as e:
            logger.error("Failed to parse JSON response: %s", e)
            logger.error("Response text: %s", response_text[:500])
            # Fallback: try to extract definitions line by line
            for concept in concepts:
                definitions_map[concept.id] = []
        
        return definitions_map
        
    except Exception as e:
        logger.error("Failed to generate definitions for batch: %s", str(e))
        # Return empty definitions for all concepts in the batch
        return {concept.id: [] for concept in concepts}


def get_concepts_without_descriptions() -> List[Concept]:
    """
    Retrieve all concepts that have a term and part_of_speech but no description.
    
    Returns:
        List of Concept objects
    """
    with Session(engine) as session:
        statement = select(Concept).where(
            Concept.term.isnot(None),
            Concept.part_of_speech.isnot(None),
            (Concept.description.is_(None) | (Concept.description == ""))
        )
        concepts = session.exec(statement).all()
        logger.info("Found %d concepts without descriptions", len(concepts))
        return list(concepts)


def update_concepts_with_descriptions(definitions_map: Dict[int, List[str]]):
    """
    Update concepts with their descriptions. If a concept has multiple definitions,
    duplicate the record for each additional definition.
    
    Args:
        definitions_map: Dictionary mapping concept_id -> list of definitions
    """
    with Session(engine) as session:
        total_updated = 0
        total_created = 0
        
        for concept_id, definitions in definitions_map.items():
            if not definitions:
                logger.warning("No definitions for concept %d, skipping", concept_id)
                continue
            
            # Get the original concept
            concept = session.get(Concept, concept_id)
            if not concept:
                logger.warning("Concept %d not found, skipping", concept_id)
                continue
            
            # Update the first concept with the first definition
            concept.description = definitions[0]
            session.add(concept)
            total_updated += 1
            
            # If there are multiple definitions, create duplicate records
            for definition in definitions[1:]:
                # Create a new concept with the same data but different description
                new_concept = Concept(
                    topic_id=concept.topic_id,
                    term=concept.term,
                    part_of_speech=concept.part_of_speech,
                    description=definition,
                    frequency_bucket=concept.frequency_bucket,
                    level=concept.level,
                    status=concept.status,
                )
                session.add(new_concept)
                total_created += 1
                logger.info("Created duplicate concept for %s (%s) with additional definition", concept.term, concept.part_of_speech)
            
            # Commit after each concept to avoid issues
            try:
                session.commit()
            except Exception as e:
                session.rollback()
                logger.error("Error updating concept %d: %s", concept_id, e)
                raise
        
        logger.info("Updated %d concepts and created %d duplicate concepts", total_updated, total_created)


def main():
    """Main function to generate descriptions for all concepts without descriptions."""
    logger.info("Starting concept description generation...")
    
    # Get concepts without descriptions
    concepts = get_concepts_without_descriptions()
    
    if not concepts:
        logger.info("No concepts without descriptions found. Exiting.")
        return
    
    logger.info("Processing %d concepts in batches of %d...", len(concepts), BATCH_SIZE)
    
    total_processed = 0
    total_batches = (len(concepts) + BATCH_SIZE - 1) // BATCH_SIZE
    
    for batch_num in range(0, len(concepts), BATCH_SIZE):
        batch = concepts[batch_num:batch_num + BATCH_SIZE]
        batch_num_display = (batch_num // BATCH_SIZE) + 1
        
        logger.info("Processing batch %d/%d (%d concepts)...", batch_num_display, total_batches, len(batch))
        
        # Generate definitions for this batch
        definitions_map = generate_definitions_batch(batch)
        
        # Update concepts with definitions
        update_concepts_with_descriptions(definitions_map)
        
        total_processed += len(batch)
        logger.info("Processed %d/%d concepts", total_processed, len(concepts))
        
        # Delay between batches to avoid rate limits
        if batch_num + BATCH_SIZE < len(concepts):
            time.sleep(API_DELAY)
    
    logger.info("Successfully completed! Processed %d concepts", total_processed)


if __name__ == "__main__":
    try:
        main()
        logger.info("Script completed successfully!")
    except Exception as e:
        logger.error("Error during script execution: %s", e, exc_info=True)
        sys.exit(1)

