# Fonts Directory

This directory contains Unicode-supporting fonts for PDF generation.

## Required Font

For proper rendering of IPA symbols and emojis in PDF exports, you need to download **Noto Sans** font.

### Quick Setup

Run this command from the project root:

```bash
cd api/fonts
curl -L -o NotoSans-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf"
```

Or using Python:

```bash
python3 -c "import urllib.request; urllib.request.urlretrieve('https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf', 'api/fonts/NotoSans-Regular.ttf')"
```

### Manual Download

1. Visit: https://fonts.google.com/noto/specimen/Noto+Sans
2. Click "Download family"
3. Extract the ZIP file
4. Copy `NotoSans-Regular.ttf` to this `api/fonts/` directory

## Font License

Noto Sans is licensed under the SIL Open Font License (OFL), which allows free use, modification, and distribution.

## Alternative Fonts

The application will also look for these fonts in system directories:
- Arial Unicode MS
- DejaVu Sans
- Liberation Sans

But bundled fonts in this directory take priority.
