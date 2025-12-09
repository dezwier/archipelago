"""
Script to populate the concept table from words.txt file.
Wipes the concept table and creates a record for each word/part-of-speech/level combination.
"""
import sys
import re
import logging
from pathlib import Path
from sqlmodel import Session, text
from app.core.database import engine
from app.models.models import Concept, CEFRLevel

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Mapping of abbreviations to full part of speech names
POS_MAPPING = {
    'n.': 'noun',
    'v.': 'verb',
    'adj.': 'adjective',
    'adv.': 'adverb',
    'prep.': 'preposition',
    'modal v.': 'modal verb',
    'conj.': 'conjunction',
    'pron.': 'pronoun',
    'det.': 'determiner',
    'exclam.': 'exclamation',
    'num.': 'numeral',
    'number': 'numeral'
}


def parse_word_line(line: str) -> list[tuple[str, str, str]]:
    """
    Parse a line from words.txt and return list of (word, part_of_speech, level) tuples.
    
    Examples:
    - "conservative adj., n. B2" -> [("conservative", "adjective", "B2"), ("conservative", "noun", "B2")]
    - "direct adj. A2, v., adv. B1" -> [("direct", "adjective", "A2"), ("direct", "verb", "B1"), ("direct", "adverb", "B1")]
    - "need v. A1, n. A2, modal v. B1" -> [("need", "verb", "A1"), ("need", "noun", "A2"), ("need", "modal verb", "B1")]
    - "according to prep. A2" -> [("according to", "preposition", "A2")]
    """
    line = line.strip()
    if not line:
        return []
    
    # Find the first POS abbreviation to separate word from POS/level info
    # This handles multi-word entries like "according to"
    word_end_pos = len(line)
    for pos_abbr in sorted(POS_MAPPING.keys(), key=len, reverse=True):
        pos_idx = line.find(pos_abbr)
        if pos_idx != -1 and pos_idx < word_end_pos:
            word_end_pos = pos_idx
    
    if word_end_pos == len(line):
        logger.warning("Could not find POS abbreviation in line: %s", line)
        return []
    
    word = line[:word_end_pos].strip()
    pos_level_str = line[word_end_pos:].strip()
    
    results = []
    
    # Split by comma to get different groups
    # Each group has format: "pos1, pos2. LEVEL" or "pos. LEVEL"
    # We need to split on commas, but a comma can be within a group (like "v., adv.")
    # The pattern is: groups are separated by comma-space-level or comma-space-POS
    # Actually, simpler: split on comma, then for each part, find the level
    
    # First, let's find all level positions to understand the structure
    level_positions = [(m.start(), m.end(), m.group(1)) for m in re.finditer(r'\b([A-C][12])\b', pos_level_str)]
    
    if not level_positions:
        logger.warning("Could not find any level in: %s (line: %s)", pos_level_str, line)
        return []
    
    # For each level, find the POS that belong to it
    # A level belongs to all POS that come before it and after the previous level
    for i, (level_start, _, level) in enumerate(level_positions):
        # Find the start of this group (either start of string or after previous level)
        if i == 0:
            group_start = 0
        else:
            # Start after the previous level and any comma/space
            prev_level_end = level_positions[i-1][1]
            group_start = prev_level_end
            # Skip comma and spaces
            while group_start < len(pos_level_str) and pos_level_str[group_start] in ', ':
                group_start += 1
        
        # The POS part is everything before this level
        pos_part = pos_level_str[group_start:level_start].strip()
        
        # Remove trailing comma if present
        pos_part = pos_part.rstrip(',').strip()
        
        # Extract all part of speech abbreviations from this group
        pos_patterns = []
        remaining_text = pos_part
        for pos_abbr in sorted(POS_MAPPING.keys(), key=len, reverse=True):  # Sort by length to match longer ones first
            if pos_abbr in remaining_text:
                pos_patterns.append(pos_abbr)
                # Remove matched POS from remaining_text to avoid double matching
                remaining_text = remaining_text.replace(pos_abbr, '', 1)
        
        # Create a record for each part of speech in this group
        for pos_abbr in pos_patterns:
            pos_full = POS_MAPPING.get(pos_abbr, pos_abbr)
            results.append((word, pos_full, level))
    
    return results


def clear_concept_table():
    """Clear all data from concept table."""
    with Session(engine) as session:
        try:
            logger.info("Deleting all concepts...")
            session.exec(text("DELETE FROM concept"))
            session.commit()
            logger.info("Successfully cleared concept table")
        except Exception as e:
            session.rollback()
            logger.error("Error clearing concept table: %s", e, exc_info=True)
            raise


def populate_concepts(words_file_path: str = None):
    """Read words.txt and populate concept table."""
    # If no path provided, look for words.txt in the same directory as this script
    if words_file_path is None:
        script_dir = Path(__file__).parent
        words_file_path = script_dir / "words.txt"
    
    try:
        with open(words_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        logger.error("File not found: %s", words_file_path)
        sys.exit(1)
    
    # Parse all lines and collect concepts
    concepts_to_create = []
    for line_num, line in enumerate(lines, 1):
        parsed = parse_word_line(line)
        for word, pos, level in parsed:
            try:
                # Validate level
                cefr_level = CEFRLevel(level)
                concepts_to_create.append({
                    'term': word,
                    'part_of_speech': pos,
                    'level': cefr_level,
                })
            except ValueError:
                logger.warning("Invalid level '%s' on line %d: %s", level, line_num, line.strip())
    
    logger.info("Parsed %d concept records from %d lines", len(concepts_to_create), len(lines))
    
    # Clear existing concepts
    clear_concept_table()
    
    # Insert all concepts
    with Session(engine) as session:
        try:
            logger.info("Inserting %d concepts...", len(concepts_to_create))
            for i, concept_data in enumerate(concepts_to_create, 1):
                concept = Concept(**concept_data)
                session.add(concept)
                
                # Commit in batches to avoid memory issues
                if i % 1000 == 0:
                    session.commit()
                    logger.info("Inserted %d/%d concepts...", i, len(concepts_to_create))
            
            session.commit()
            logger.info("Successfully inserted %d concepts", len(concepts_to_create))
            
        except Exception as e:
            session.rollback()
            logger.error("Error inserting concepts: %s", e, exc_info=True)
            raise


if __name__ == "__main__":
    logger.info("Starting concept population...")
    try:
        populate_concepts()
        logger.info("Successfully completed!")
    except Exception as e:
        logger.error("Error during concept population: %s", e, exc_info=True)
        sys.exit(1)

