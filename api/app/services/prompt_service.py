"""
Service for generating LLM prompts.
"""
from typing import Optional


def generate_lemma_system_instruction(
    term: str,
    description: Optional[str] = None,
    part_of_speech: Optional[str] = None
) -> str:
    """
    Generate the system instruction for lemma generation.
    This provides reusable context that can be sent once and reused for multiple languages.
    
    Args:
        term: The term to translate (can be a single word, phrase, or full sentence)
        description: Optional description/context for the term
        part_of_speech: Optional part of speech (will be inferred if not provided)
        
    Returns:
        The system instruction string
    """
    # Handle part of speech
    part_of_speech_text = ""
    if part_of_speech:
        part_of_speech_text = f"\nPart of speech: {part_of_speech}"
    else:
        part_of_speech_text = "\nPart of speech: NOT PROVIDED - You must infer the part of speech from the term itself. The term can be a single word, a phrase, or a full sentence. For single words, determine if it's a noun, verb, adjective, adverb, etc. For phrases or sentences, infer the most appropriate grammatical part of speech based on the primary word or structure."
    
    # Handle description/context
    description_text = ""
    if description:
        description_text = f"\nDescription/Context: {description}\n\nCRITICAL: The term \"{term}\" may have multiple meanings, but you MUST use ONLY the specific meaning provided in the Description above. Ignore all other meanings this term might have. Your translation and description must reflect ONLY this exact semantic meaning."
    else:
        description_text = "\nIMPORTANT: No description was provided. You must infer ONE specific semantic meaning for this term. For single words, choose the most common or primary meaning. For phrases or sentences, understand the action or concept being expressed."
    
    system_instruction = f"""You are a language learning assistant. Your task is to generate lemmas (translations and lemma data) for language learning flashcards.

Context for the current term:
Term: {term}{part_of_speech_text}{description_text}

The term can be:
- A single word (e.g., "hello", "run", "beautiful")
- A phrase (e.g., "how are you", "good morning", "thank you very much")
- A full sentence (e.g., "I love you", "Where is the bathroom?", "Can you help me?")

When given a target language, you must:
1. Translate the term accurately to the target language (for phrases/sentences, translate naturally, not word-for-word)
2. Generate a description in the target language:
   - For single words: Provide a lemma definition (what the word means)
   - For phrases/sentences: Describe the action, situation, or meaning being expressed in SIMPLE TERMS in the target language. CRITICAL: Do NOT mention or repeat the important words from the sentence in the description. Instead, describe what the sentence means or expresses using different, simpler words.
   - Write naturally in the target language, do NOT translate word-for-word from English
3. Provide IPA pronunciation using standard IPA symbols
4. Include language-specific fields ONLY when applicable:
   - For SINGLE WORDS: Include gender, article, plural_form, verb_type, auxiliary_verb when applicable
   - For PHRASES/SENTENCES: These fields should be null (they don't apply to multi-word expressions)
5. Use null for non-applicable fields
6. Always return valid JSON in the specified format

IMPORTANT - Valid values:
- part_of_speech (if inferring): Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection
- gender: Must be one of: masculine, feminine, neuter, or null (only for single words)
- register: Must be one of: neutral, formal, informal, slang, or null

Rules:
1. The term can be a single word, phrase, OR full sentence - handle all appropriately
2. For single words that are verbs: Use infinitive form
3. For phrases/sentences: Translate naturally and idiomatically, preserving the meaning
4. Fields "term", "description", and "ipa" are REQUIRED and cannot be null or empty
5. For phrases/sentences: Set gender, article, plural_form, verb_type, and auxiliary_verb to null
6. The description should explain what the term means or what action/situation it expresses
7. For sentences: The description must be written in simple terms in the target language and MUST NOT mention or repeat the important words from the sentence. Use different, simpler words to describe the meaning."""
    
    return system_instruction


def generate_lemma_user_prompt(target_language: str) -> str:
    """
    Generate the user prompt for a specific target language.
    This is a simple prompt that just specifies the target language and expected output format.
    The system instruction provides all the context about the term.
    
    Args:
        target_language: Target language code to translate to
        
    Returns:
        The user prompt string
    """
    prompt = f"""Translate to {target_language.upper()} and return ONLY valid JSON in this exact format (no markdown, no explanations):
{{
  "term": "string (the translation in {target_language.upper()}. For single words that are verbs, use infinitive form. For phrases/sentences, translate naturally and idiomatically)",
  "ipa": "string or null (pronunciation in standard IPA symbols)",
  "description": "string (REQUIRED - generate a description in {target_language.upper()}, do NOT translate from English, write naturally in {target_language.upper()}. For single words: provide a definition. For phrases/sentences: describe the action or meaning being expressed in SIMPLE TERMS without mentioning or repeating the important words from the sentence)",
  "gender": "masculine | feminine | neuter | null (ONLY for single words in languages with gender, null for phrases/sentences)",
  "article": "string or null (ONLY for single words in languages with articles, null for phrases/sentences)",
  "plural_form": "string or null (ONLY for single-word nouns, null for phrases/sentences)",
  "verb_type": "string or null (ONLY for single-word verbs, null for phrases/sentences)",
  "auxiliary_verb": "string or null (ONLY for single-word verbs in languages like French, null for phrases/sentences)",
  "register": "neutral | formal | informal | slang | null"
}}

IMPORTANT:
- If the term is a phrase or sentence, set gender, article, plural_form, verb_type, and auxiliary_verb to null
- These fields only apply to single words, not to multi-word expressions"""
    
    return prompt


def generate_lemma_prompt(
    term: str,
    target_language: str,
    description: Optional[str] = None,
    part_of_speech: Optional[str] = None
) -> tuple[str, str]:
    """
    Generate both system instruction and user prompt for lemma generation.
    This is a convenience function that returns both for single-call scenarios.
    
    Args:
        term: The term to translate (can be a single word, phrase, or full sentence)
        target_language: Target language code to translate to
        description: Optional description/context for the term
        part_of_speech: Optional part of speech (will be inferred if not provided)
        
    Returns:
        Tuple of (system_instruction, user_prompt)
    """
    system_instruction = generate_lemma_system_instruction(
        term=term,
        description=description,
        part_of_speech=part_of_speech
    )
    
    user_prompt = generate_lemma_user_prompt(target_language=target_language)
    
    return system_instruction, user_prompt

