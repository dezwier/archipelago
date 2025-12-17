#!/usr/bin/env python3
"""
Download Noto Sans Arabic font for PDF generation.
Run this script to ensure Arabic text renders correctly in PDF exports.
"""
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
# Use the official noto-fonts repository - Noto Sans Arabic for proper Arabic rendering
FONT_URL = "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf"
FONT_FILE = SCRIPT_DIR / "NotoSansArabic-Regular.ttf"

def download_font():
    """Download Noto Sans Arabic font if not already present."""
    if FONT_FILE.exists():
        print(f"✓ Font already exists: {FONT_FILE}")
        print(f"  Size: {FONT_FILE.stat().st_size / 1024:.1f} KB")
        return True
    
    print("Downloading Noto Sans Arabic font...")
    try:
        req = urllib.request.Request(FONT_URL)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)')
        with urllib.request.urlopen(req, timeout=30) as response:
            with open(FONT_FILE, 'wb') as f:
                f.write(response.read())
        if FONT_FILE.exists():
            size_kb = FONT_FILE.stat().st_size / 1024
            print(f"✓ Successfully downloaded Noto Sans Arabic font to {FONT_FILE}")
            print(f"  Size: {size_kb:.1f} KB")
            return True
        else:
            print("✗ Failed to download font")
            return False
    except Exception as e:
        print(f"✗ Error downloading font: {e}")
        return False

if __name__ == "__main__":
    download_font()
