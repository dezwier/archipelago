"""
Text utility functions.
"""


def ensure_capitalized(text: str) -> str:
    """
    Ensure the first letter is capitalized while preserving the rest of the case.
    If text is empty, return as is.
    
    Args:
        text: The text to capitalize
        
    Returns:
        Text with first letter capitalized
    """
    if not text:
        return text
    return text[0].upper() + text[1:] if len(text) > 0 else text


def normalize_lemma_term(term: str) -> str:
    """
    Normalize a lemma term by trimming leading and trailing dots (.) and whitespace.
    Other symbols like question marks, exclamation marks, etc. are preserved.
    
    Args:
        term: The term to normalize
        
    Returns:
        Normalized term with leading/trailing dots and whitespace removed
    """
    if not term:
        return term
    
    # Strip leading and trailing whitespace first
    normalized = term.strip()
    
    # Strip leading dots
    while normalized.startswith('.'):
        normalized = normalized[1:]
    
    # Strip trailing dots
    while normalized.endswith('.'):
        normalized = normalized[:-1]
    
    # Strip any remaining leading/trailing whitespace that might have been exposed
    normalized = normalized.strip()
    
    return normalized

