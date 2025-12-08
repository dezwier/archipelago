"""
Script to populate concept table with top 3000 most frequent English words.
Reads from frequent_words.txt and enriches with WordNet data.
Uses frequency data to assign proper frequency buckets.
"""
import sys
from pathlib import Path
from sqlmodel import Session, select
from app.core.database import engine
from app.models.models import Concept
import nltk
from nltk.corpus import wordnet as wn
from collections import Counter
import requests
import logging

# Download required NLTK data (run once)
try:
    nltk.data.find('corpora/wordnet')
except LookupError:
    print("Downloading WordNet data...")
    nltk.download('wordnet', quiet=True)

try:
    nltk.data.find('corpora/brown')
except LookupError:
    print("Downloading Brown corpus for frequency data...")
    nltk.download('brown', quiet=True)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# POS mapping from WordNet to readable format
POS_MAP = {
    'n': 'noun',
    'v': 'verb',
    'a': 'adjective',
    's': 'adjective',  # satellite adjective
    'r': 'adverb'
}


def get_frequency_bucket(rank: int) -> str:
    """Assign frequency bucket based on rank."""
    if rank <= 1000:
        return "1-1000"
    elif rank <= 2000:
        return "1001-2000"
    elif rank <= 3000:
        return "2001-3000"
    else:
        return "3001+"


def download_frequency_list() -> dict[str, int]:
    """
    Download a frequency-ranked word list and return a mapping of word -> rank.
    Uses a public frequency word list from GitHub.
    """
    url = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2016/en/en_50k.txt"
    
    try:
        logger.info("Downloading frequency word list...")
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        word_to_rank = {}
        for rank, line in enumerate(response.text.strip().split('\n'), start=1):
            if line.strip():
                # Format is usually "word frequency" or just "word"
                parts = line.strip().split()
                if parts:
                    word = parts[0].lower()
                    word_to_rank[word] = rank
        
        logger.info("Downloaded frequency list with %d words", len(word_to_rank))
        return word_to_rank
        
    except Exception as e:
        logger.warning("Failed to download frequency list: %s", e)
        logger.info("Falling back to Brown corpus frequency calculation...")
        return calculate_frequency_from_corpus()


def calculate_frequency_from_corpus() -> dict[str, int]:
    """
    Calculate word frequencies from NLTK Brown corpus and return word -> rank mapping.
    This is a fallback if we can't download a frequency list.
    """
    try:
        from nltk.corpus import brown
        
        logger.info("Calculating word frequencies from Brown corpus...")
        # Get all words from Brown corpus
        words = [word.lower() for word in brown.words() if word.isalpha()]
        
        # Count frequencies
        word_freq = Counter(words)
        
        # Sort by frequency (descending) and assign ranks
        sorted_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        
        word_to_rank = {}
        for rank, (word, _) in enumerate(sorted_words, start=1):
            word_to_rank[word] = rank
        
        logger.info("Calculated frequencies for %d words from Brown corpus", len(word_to_rank))
        return word_to_rank
        
    except Exception as e:
        logger.error("Failed to calculate frequencies from corpus: %s", e)
        return {}


def get_wordnet_data(word: str) -> tuple[str | None, str | None]:
    """
    Get description and part of speech from WordNet.
    Returns (description, part_of_speech) or (None, None) if not found.
    """
    # Get all synsets for the word
    synsets = wn.synsets(word.lower())
    
    if not synsets:
        return None, None
    
    # Prefer noun, then verb, then adjective, then adverb
    preferred_pos = ['n', 'v', 'a', 'r', 's']
    
    # Find the best synset (prefer most common POS)
    best_synset = None
    for pos in preferred_pos:
        for synset in synsets:
            if synset.pos() == pos:
                best_synset = synset
                break
        if best_synset:
            break
    
    # If no preferred POS found, use the first synset
    if not best_synset:
        best_synset = synsets[0]
    
    # Get definition (gloss)
    definition = best_synset.definition()
    
    # Get POS
    pos_code = best_synset.pos()
    pos_readable = POS_MAP.get(pos_code, pos_code)
    
    return definition, pos_readable


def get_wordnet_meanings_by_pos(word: str) -> list[tuple[str, str]]:
    """
    Get meanings grouped by part of speech from WordNet for a word.
    Returns a list of (description, part_of_speech) tuples, one per unique POS.
    Each tuple represents a concept for that part of speech (using the first description found for that POS).
    Only returns entries where both description and part_of_speech are available.
    """
    # Get all synsets for the word
    synsets = wn.synsets(word.lower())
    
    if not synsets:
        return []
    
    # Group by part of speech, taking the first description for each POS
    pos_to_description = {}
    
    for synset in synsets:
        definition = synset.definition()
        pos_code = synset.pos()
        pos_readable = POS_MAP.get(pos_code, pos_code)
        
        # Only add if we have both description and POS, and haven't seen this POS yet
        if definition and pos_readable and pos_readable not in pos_to_description:
            pos_to_description[pos_readable] = definition
    
    # Convert to list of tuples
    return [(desc, pos) for pos, desc in pos_to_description.items()]


def read_frequent_words(file_path: Path) -> list[str]:
    """Read words from the frequent words file."""
    words = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip()
            if word:
                words.append(word)
    return words


def populate_concepts(batch_size: int = 100):
    """
    Populate concept table with words from the frequent_words.txt file.
    
    Args:
        batch_size: Number of concepts to insert per transaction
    """
    # Get file path relative to this script
    script_dir = Path(__file__).parent
    words_file = script_dir / "app" / "core" / "frequent_words.txt"
    
    if not words_file.exists():
        logger.error("Word list file not found: %s", words_file)
        sys.exit(1)
    
    words = read_frequent_words(words_file)
    total_words = len(words)
    logger.info("Found %d words to process", total_words)
    
    # Get frequency rankings
    logger.info("Loading frequency data...")
    frequency_map = download_frequency_list()
    
    if not frequency_map:
        logger.error("Could not obtain frequency data. Cannot assign frequency buckets.")
        sys.exit(1)
    
    with Session(engine) as session:
        # Check existing concepts to avoid duplicates
        # We check for (term, description) combinations to avoid duplicates
        existing_concepts = session.exec(
            select(Concept.term, Concept.description).where(Concept.term.isnot(None))
        ).all()
        existing_concept_pairs = {
            (term.lower() if term else None, description) 
            for term, description in existing_concepts
        }
        logger.info("Found %d existing concepts in database", len(existing_concept_pairs))
        
        concepts_to_insert = []
        skipped = 0
        not_found = 0
        no_frequency = 0
        processed = 0
        total_concepts_created = 0
        
        for word in words:
            word_lower = word.lower()
            
            # Get frequency rank from frequency map
            frequency_rank = frequency_map.get(word_lower)
            
            if frequency_rank is None:
                no_frequency += 1
                logger.warning("No frequency data found for: %s, assigning to 3001+ bucket", word)
                frequency_rank = 999999  # High number for unknown words
            
            # Get WordNet meanings grouped by part of speech
            meanings = get_wordnet_meanings_by_pos(word)
            
            if not meanings:
                not_found += 1
                logger.warning("No WordNet data with both POS and description found for: %s", word)
                # Skip words without both POS and description
                skipped += 1
            else:
                # Create a concept for each part of speech
                frequency_bucket = get_frequency_bucket(frequency_rank)
                
                for description, part_of_speech in meanings:
                    concept_key = (word_lower, description)
                    
                    # Skip if this exact (term, description) combination already exists
                    if concept_key in existing_concept_pairs:
                        skipped += 1
                        continue
                    
                    concept = Concept(
                        term=word,
                        description=description,
                        part_of_speech=part_of_speech,
                        frequency_bucket=frequency_bucket,
                        status="active"
                    )
                    
                    concepts_to_insert.append(concept)
                    existing_concept_pairs.add(concept_key)
                    total_concepts_created += 1
            
            processed += 1
            
            # Progress update every 100 words
            if processed % 100 == 0:
                logger.info("Processed %d/%d words (skipped: %d, not found: %d, no frequency: %d, concepts created: %d)", 
                          processed, total_words, skipped, not_found, no_frequency, total_concepts_created)
            
            # Insert in batches
            if len(concepts_to_insert) >= batch_size:
                try:
                    session.add_all(concepts_to_insert)
                    session.commit()
                    logger.info("Inserted batch of %d concepts", len(concepts_to_insert))
                    concepts_to_insert = []
                except Exception as e:
                    session.rollback()
                    logger.error("Error inserting batch: %s", e)
                    raise
        
        # Insert remaining concepts
        if concepts_to_insert:
            try:
                session.add_all(concepts_to_insert)
                session.commit()
                logger.info("Inserted final batch of %d concepts", len(concepts_to_insert))
            except Exception as e:
                session.rollback()
                logger.error("Error inserting final batch: %s", e)
                raise
        
        logger.info("Completed! Processed %d words", total_words)
        logger.info("  - Skipped (already exists): %d", skipped)
        logger.info("  - Not found in WordNet: %d", not_found)
        logger.info("  - No frequency data: %d", no_frequency)
        logger.info("  - Concepts created: %d", total_concepts_created)
        logger.info("  - Total concepts to insert: %d", len(concepts_to_insert))


if __name__ == "__main__":
    # Get file path
    script_dir_path = Path(__file__).parent
    words_file_path = script_dir_path / "app" / "core" / "frequent_words.txt"
    
    if not words_file_path.exists():
        logger.error("Word list file not found: %s", words_file_path)
        logger.error("Please ensure frequent_words.txt exists in api/app/core/")
        sys.exit(1)
    
    logger.info("Starting concept population...")
    logger.info("Reading words from: %s", words_file_path)
    
    try:
        populate_concepts()
        logger.info("Successfully completed!")
    except Exception as e:
        logger.error("Error during population: %s", e, exc_info=True)
        sys.exit(1)

