"""
Helper functions for generating LLM prompts.
"""
from typing import List, Optional


def build_concept_context(
    term: str,
    part_of_speech: Optional[str],
    description: Optional[str] = None,
    core_meaning_en: Optional[str] = None,
    excluded_senses: Optional[List[str]] = None
) -> tuple[str, str, str]:
    """
    Build the shared context components for concept prompts.
    This function is used by both generate_concept_prompt and generate_card_translation_system_instruction.
    
    Args:
        term: The term
        part_of_speech: Part of speech (optional)
        description: Existing description (for existing concepts)
        core_meaning_en: Core meaning in English (for new concepts)
        excluded_senses: List of excluded senses (for new concepts)
        
    Returns:
        Tuple of (part_of_speech_text, meaning_instruction, excluded_text)
    """
    # Handle part of speech
    part_of_speech_text = ""
    if part_of_speech:
        part_of_speech_text = f"\nPart of speech: {part_of_speech}"
    else:
        part_of_speech_text = "\nPart of speech: NOT PROVIDED - You must infer the part of speech from the term itself. Analyze the term to determine if it's a noun, verb, adjective, adverb, etc."
    
    # Handle meaning/description
    meaning_instruction = ""
    if description:
        # For existing concepts with description
        meaning_instruction = f"\n\nCRITICAL: The term \"{term}\" may have multiple meanings, but you MUST use ONLY the specific meaning provided in the Description above. Ignore all other meanings this term might have. Your translation and description must reflect ONLY this exact semantic meaning."
    elif core_meaning_en:
        # For new concepts with provided core meaning
        meaning_instruction = f"\nCore meaning in English: {core_meaning_en}\nUse this exact meaning for all language cards."
    else:
        # For new concepts without core meaning
        meaning_instruction = "\nIMPORTANT: No core meaning was provided. You must infer ONE specific semantic meaning for this term based on its part of speech and common usage. Choose the most common or primary meaning. All cards across all languages MUST represent this exact same semantic concept."
    
    # Handle excluded senses (only for new concepts)
    excluded_text = ""
    if excluded_senses:
        excluded_text = f"\nExcluded senses (do not include these meanings): {', '.join(excluded_senses)}"
    
    return part_of_speech_text, meaning_instruction, excluded_text


def generate_concept_prompt(
    term: str,
    part_of_speech: Optional[str],
    core_meaning_en: Optional[str],
    excluded_senses: List[str],
    languages: List[str]
) -> str:
    """
    Generate the prompt for the LLM to create a new concept with cards.
    
    Args:
        term: The term to generate concept for
        part_of_speech: Part of speech (optional - will be inferred if not provided)
        core_meaning_en: Core meaning in English (optional)
        excluded_senses: List of excluded senses
        languages: List of language codes
        
    Returns:
        The prompt string
    """
    # Build shared context components
    part_of_speech_instruction, core_meaning_instruction, excluded_text = build_concept_context(
        term=term,
        part_of_speech=part_of_speech,
        core_meaning_en=core_meaning_en,
        excluded_senses=excluded_senses
    )
    
    prompt = f"""You are a language learning assistant. Generate concept and card data for the term "{term}".{part_of_speech_instruction}{core_meaning_instruction}{excluded_text}

Generate data for the following languages: {', '.join(languages)}

Return ONLY valid JSON in this exact format (no markdown, no explanations):
{{
  "concept": {{
    "description": "string describing the concept in English (the core semantic meaning)",
    "frequency_bucket": "very high | high | medium | low | very low"
  }},
  "cards": [
    {{
      "language_code": "en",
      "term": "string (use infinitive for verbs)",
      "ipa": "string or null (use standard IPA symbols)",
      "description": "string (REQUIRED - in the target language, do NOT translate from English)",
      "gender": "masculine | feminine | neuter | null (for languages with gender)",
      "article": "string or null (for languages with articles)",
      "plural_form": "string or null (for nouns)",
      "verb_type": "string or null (for verbs)",
      "auxiliary_verb": "string or null (for verbs in languages like French)",
      "register": "neutral | formal | informal | slang | null"
    }}
  ]
}}

IMPORTANT - Valid values:
- part_of_speech (if inferring): Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence
- frequency_bucket: Must be one of: very high, high, medium, low, very low
- gender: Must be one of: masculine, feminine, neuter, or null

Rules:
1. Generate exactly one card per requested language
2. CRITICAL: All cards must express the EXACT SAME core semantic meaning across all languages
3. If no core meaning was provided, infer ONE specific meaning and ensure ALL language cards represent that same meaning consistently
4. If part of speech was not provided, you must infer it from the term - analyze the term's form, context, and common usage patterns. The part of speech must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence
5. Use infinitive form for verbs
6. Use null for non-applicable fields
7. IPA must use standard IPA symbols
8. Descriptions should be in the target language, not translated from English
9. All cards must represent the same semantic concept - consistency across languages is essential
10. The concept description should clearly define the single semantic meaning that all cards share
11. frequency_bucket must be exactly one of: "very high", "high", "medium", "low", or "very low"
12. gender must be exactly one of: "masculine", "feminine", "neuter", or null
13. REQUIRED FIELDS: Both "term" and "description" are REQUIRED for each card - they cannot be missing, empty, or null"""
    
    return prompt


def generate_card_translation_system_instruction(
    term: str,
    description: Optional[str],
    part_of_speech: Optional[str]
) -> str:
    """
    Generate a system instruction that provides context once per concept.
    This context is reused for all language translations.
    
    Args:
        term: The English term to translate
        description: The English description of the concept
        part_of_speech: Part of speech
        
    Returns:
        The system instruction string
    """
    # Build shared context components
    part_of_speech_text, meaning_instruction, _ = build_concept_context(
        term=term,
        part_of_speech=part_of_speech,
        description=description
    )
    
    description_text = ""
    if description:
        description_text = f"\nDescription: {description}"
    
    system_instruction = f"""You are a language learning assistant. Your task is to translate terms and generate card data for language learning flashcards.

Context for the current concept:
Term: {term}{part_of_speech_text}{description_text}{meaning_instruction}

When asked to translate to a specific language, you must:
1. Translate the term accurately to the target language
2. Generate a description in the target language (do NOT translate word-for-word from English, write naturally in the target language)
3. Provide IPA pronunciation
4. Include language-specific fields (gender, article, plural_form, verb_type, auxiliary_verb, register) when applicable
5. Use null for non-applicable fields
6. Always return valid JSON in the specified format"""
    
    return system_instruction


def generate_card_translation_user_prompt(target_language: str) -> str:
    """
    Generate a simple user prompt for translating to a specific language.
    This is used with the system instruction to avoid repeating context.
    
    This function is shared and reused by both the generate screen and dictionary screen.
    
    Args:
        target_language: Target language code
        
    Returns:
        The user prompt string
    """
    prompt = f"""Translate to {target_language.upper()} and return ONLY valid JSON in this exact format (no markdown, no explanations):
{{
  "term": "string (the translation in {target_language.upper()}, use infinitive for verbs)",
  "ipa": "string or null (pronunciation in standard IPA symbols)",
  "description": "string (REQUIRED - generate a description in {target_language.upper()}, do NOT translate from English, write naturally in {target_language.upper()})",
  "gender": "masculine | feminine | neuter | null (for languages with gender)",
  "article": "string or null (for languages with articles)",
  "plural_form": "string or null (for nouns)",
  "verb_type": "string or null (for verbs)",
  "auxiliary_verb": "string or null (for verbs in languages like French)",
  "register": "neutral | formal | informal | slang | null"
}}

IMPORTANT:
- Translate the term into {target_language.upper()}
- Generate a description in {target_language.upper()} (IMPORTANT: write the description naturally in {target_language.upper()}, do not translate word-for-word from English)
- The description should be a lemma definition of the term in {target_language.upper()}
- Provide IPA pronunciation
- Include gender, article, plural_form, and register if applicable for the language. Use null for non-applicable fields
- Fields "term", "description", "ipa" are REQUIRED and cannot be null or empty"""
    
    return prompt

