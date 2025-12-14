#!/bin/bash
# Download Noto Sans font for PDF generation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_URL="https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf"
FONT_FILE="$SCRIPT_DIR/NotoSans-Regular.ttf"

echo "Downloading Noto Sans font..."
curl -L -o "$FONT_FILE" "$FONT_URL"

if [ -f "$FONT_FILE" ]; then
    echo "✓ Successfully downloaded Noto Sans font to $FONT_FILE"
    echo "Font size: $(du -h "$FONT_FILE" | cut -f1)"
else
    echo "✗ Failed to download font"
    exit 1
fi
