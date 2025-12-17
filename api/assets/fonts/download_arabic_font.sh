#!/bin/bash
# Download Noto Sans Arabic font for PDF generation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_URL="https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf"
FONT_FILE="$SCRIPT_DIR/NotoSansArabic-Regular.ttf"

if [ -f "$FONT_FILE" ]; then
    echo "✓ Font already exists: $FONT_FILE"
    echo "Font size: $(du -h "$FONT_FILE" | cut -f1)"
    exit 0
fi

echo "Downloading Noto Sans Arabic font..."
curl -L -o "$FONT_FILE" "$FONT_URL"

if [ -f "$FONT_FILE" ]; then
    echo "✓ Successfully downloaded Noto Sans Arabic font to $FONT_FILE"
    echo "Font size: $(du -h "$FONT_FILE" | cut -f1)"
else
    echo "✗ Failed to download font"
    exit 1
fi




