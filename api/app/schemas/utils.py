"""
Utility functions for schema validation.
"""
from typing import Optional


def normalize_part_of_speech(v: Optional[str]) -> Optional[str]:
    """
    Normalize part_of_speech value to proper case.
    Handles both lowercase and capitalized inputs.
    Converts deprecated values ('Saying', 'Sentence') to None.
    
    Args:
        v: Part of speech value (can be None, lowercase, or capitalized)
        
    Returns:
        Normalized part of speech value in proper case, or None
    """
    if v is None:
        return None
    
    v_normalized = v.strip()
    if not v_normalized:
        return None
    
    # Handle deprecated values - convert to None (missing)
    v_lower = v_normalized.lower()
    deprecated_values = {'saying', 'sentence'}
    if v_lower in deprecated_values:
        return None
    
    # Map of lowercase to proper case
    pos_map = {
        'noun': 'Noun',
        'verb': 'Verb',
        'adjective': 'Adjective',
        'adverb': 'Adverb',
        'pronoun': 'Pronoun',
        'preposition': 'Preposition',
        'conjunction': 'Conjunction',
        'determiner / article': 'Determiner / Article',
        'determiner': 'Determiner / Article',
        'article': 'Determiner / Article',
        'interjection': 'Interjection'
    }
    
    # Try to normalize
    if v_lower in pos_map:
        return pos_map[v_lower]
    
    # If already in proper format, check if valid
    valid_values = ['Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 'Conjunction', 'Determiner / Article', 'Interjection']
    if v_normalized in valid_values:
        return v_normalized
    
    # If not found, raise error
    raise ValueError(f"part_of_speech must be one of: {', '.join(valid_values)}. Got: {v}")

