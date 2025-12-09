"""
Helper functions for LLM API calls.
"""
import requests
import json
import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)


def calculate_gemini_cost(prompt_tokens: int, output_tokens: int, model_name: str = "gemini-2.5-flash") -> float:
    """
    Calculate cost for Gemini API call based on token usage.
    
    Pricing (as of 2024):
    - gemini-2.5-flash: $0.075 per 1M input tokens, $0.30 per 1M output tokens
    - gemini-2.5-pro: $0.125 per 1M input tokens, $0.50 per 1M output tokens
    
    Args:
        prompt_tokens: Number of input tokens
        output_tokens: Number of output tokens
        model_name: Name of the model used
        
    Returns:
        Cost in USD
    """
    # Pricing per million tokens
    if "flash" in model_name.lower():
        input_price_per_million = 0.075
        output_price_per_million = 0.30
    elif "pro" in model_name.lower():
        input_price_per_million = 0.125
        output_price_per_million = 0.50
    else:
        # Default to flash pricing
        input_price_per_million = 0.075
        output_price_per_million = 0.30
    
    input_cost = (prompt_tokens / 1_000_000) * input_price_per_million
    output_cost = (output_tokens / 1_000_000) * output_price_per_million
    
    return input_cost + output_cost


def call_gemini_api(prompt: str, system_instruction: Optional[str] = None) -> tuple[dict, dict]:
    """
    Call Gemini API to generate concept and card data.
    
    Args:
        prompt: The prompt to send to the LLM
        system_instruction: Optional system instruction to provide context (sent once, reused for multiple calls)
        
    Returns:
        Tuple of (parsed JSON response from the LLM, token usage dict with keys:
                  'prompt_tokens', 'output_tokens', 'total_tokens', 'cost_usd', 'model_name')
        
    Raises:
        Exception: If API call fails or response is invalid
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
    
    # Add system instruction if provided
    if system_instruction:
        payload["systemInstruction"] = {
            "parts": [{
                "text": system_instruction
            }]
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
        
        # Extract token usage from usageMetadata
        usage_metadata = data.get('usageMetadata', {})
        prompt_tokens = usage_metadata.get('promptTokenCount', 0)
        output_tokens = usage_metadata.get('candidatesTokenCount', 0)
        total_tokens = usage_metadata.get('totalTokenCount', prompt_tokens + output_tokens)
        
        # Calculate cost
        cost_usd = calculate_gemini_cost(prompt_tokens, output_tokens, model_name)
        
        token_usage = {
            'prompt_tokens': prompt_tokens,
            'output_tokens': output_tokens,
            'total_tokens': total_tokens,
            'cost_usd': cost_usd,
            'model_name': model_name
        }
        
        # Extract generated text
        if 'candidates' in data and len(data['candidates']) > 0:
            candidate = data['candidates'][0]
            if 'content' in candidate and 'parts' in candidate['content']:
                text = candidate['content']['parts'][0].get('text', '').strip()
                if not text:
                    raise Exception("LLM returned empty response")
                
                # Try to extract JSON from the response
                # The LLM might return markdown code blocks or plain JSON
                text = text.strip()
                if text.startswith('```'):
                    # Remove markdown code blocks
                    lines = text.split('\n')
                    text = '\n'.join(lines[1:-1]) if lines[0].startswith('```') else text
                    if text.endswith('```'):
                        text = text[:-3]
                
                # Parse JSON
                try:
                    llm_data = json.loads(text)
                    return llm_data, token_usage
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse LLM JSON response: {e}")
                    logger.error(f"Response text: {text[:500]}")
                    raise Exception(f"LLM returned invalid JSON: {str(e)}")
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

