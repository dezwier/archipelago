# Fonts Directory

This directory contains Unicode-supporting fonts for PDF generation.

## Required Fonts

### Noto Sans (for IPA symbols and emojis)

For proper rendering of IPA symbols and emojis in PDF exports, you need to download **Noto Sans** font.

#### Quick Setup

Run this command from the project root:

```bash
cd api/assets/fonts
curl -L -o NotoSans-Regular.ttf "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf"
```

Or using Python:

```bash
python3 api/assets/fonts/download_font.py
```

Or using the shell script:

```bash
./api/assets/fonts/download_font.sh
```

### Noto Sans Arabic (for Arabic text)

For proper rendering of Arabic text in PDF exports, you need to download **Noto Sans Arabic** font.

#### Quick Setup

Run this command from the project root:

```bash
cd api/assets/fonts
python3 download_arabic_font.py
```

Or using the shell script:

```bash
./api/assets/fonts/download_arabic_font.sh
```

Or manually:

```bash
cd api/assets/fonts
curl -L -o NotoSansArabic-Regular.ttf "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf"
```

### Manual Download

1. **Noto Sans**: Visit https://fonts.google.com/noto/specimen/Noto+Sans
2. **Noto Sans Arabic**: Visit https://fonts.google.com/noto/specimen/Noto+Sans+Arabic
3. Click "Download family" for each
4. Extract the ZIP files
5. Copy `NotoSans-Regular.ttf` and `NotoSansArabic-Regular.ttf` to this `api/assets/fonts/` directory

## Font License

Noto Sans fonts are licensed under the SIL Open Font License (OFL), which allows free use, modification, and distribution.

## Alternative Fonts

The application will also look for these fonts in system directories:
- Arial Unicode MS
- DejaVu Sans
- Liberation Sans

But bundled fonts in this directory take priority.
