"""
Utility functions for endpoint operations.
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

