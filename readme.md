## Vision
- A useful app to actually learn a language
    - Starting languages: English, Italian, French, Spanish, German, Japanese, Lithuanian, Dutch
- Uses concepts
    - Pronunciation first
    - Don't translate
    - Spaced repetition (SRS)

## Technical Breakdown
- A frontend app made with flutter to generate both in iOS, Android and web
    - Screen to generate flashcards
        - Enter a word or phrase, services will retrieve a description, ipa, audio recording, google images etc
        - Entering can also be long, then it will be considered a topic island, which will be broken down in flashcards same as above
        - Entering can be written or speech
    - Screen to practice flashcards
        - Either new, or seen ones depending on availability, according SRS
        - Showing the image and description of the target language, the translation of native language hidden
        - Showing estimated retention curve afterwards
    - Screen with profile and stats
        - What languages, words learned
        - bin distribution of words according SRS


- A backend using Postgres and Railway to have single point of truths for all platforms
- Database model
    - Concept
        - id (pk, bigint)
        - internal_name
        - image_path_1 (string)
        - image_path_2 (string)
        - image_path_3 (string)
        - image_path_4 (string)
        - topic_id (fk, int)

    - Language
        - code (PK, char(2)) - e.g., 'en', 'fr', 'es', 'jp'
        - name (string) - English, French, etc.

    - Card
        - id (PK, bigint)
        - concept_id (FK) - Links back to the concept.
        - language_code (FK) - Links to Language table.
        - translation (string) - The world in the target language
        - description (string) - A description in the target language
        - ipa (string) - Pronunciation in IPA symbols
        - audio_path (string) - Pronunciation file.
        - gender (string, nullable) - Crucial for French/Spanish/German.
        - notes (string) - Context specific to this language.

    - UserCard
        - id (PK, bigint)
        - user_id (FK)
        - card_id (FK)
        - image_path (string)
        - created_time (timestamp)
        - last_success_time (timestamp)
        - status (enum)
        - next_review_at (timestamp) - Calculated by SRS.

    - User
        - id (PK)
        - lang_native (string)
        - lang_learning (string)

    - UserPractice
        - id (PK)
        - user_id (fk)
        - created_time (time)
        - success (bool)
        - feedback (int)