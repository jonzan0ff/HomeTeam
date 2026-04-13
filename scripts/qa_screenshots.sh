#!/bin/bash
# HomeTeam QA Widget Screenshots
# Captures dim and lit mode for NHL, MotoGP, F1 widgets on the QA Mac.
# Produces 6 images per build. Retains latest 10 builds.
#
# Usage: ./scripts/qa_screenshots.sh <version>
# Example: ./scripts/qa_screenshots.sh v1.4.0
#
# Prerequisites:
#   - QA Mac reachable at qa@iMac.local
#   - HomeTeam running with 3 widgets on desktop (NHL, MotoGP, F1 left-to-right)
#   - No other windows covering the widgets

set -euo pipefail

VERSION="${1:?Usage: qa_screenshots.sh <version>}"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
QA_HOST="qa@iMac.local"
QA_DIR="$HOME/Documents/jonzan0ff/Projects/HomeTeam/qa"
SCREENSHOTS_DIR="$QA_DIR/screenshots"

# Widget crop coordinates (4480x2520 Retina 4.5K iMac)
# Format: sips -c <height> <width> --cropOffset <y> <x>
CROP_H=730
CROP_W=720
CROP_Y=30
NHL_X=2150
MOTOGP_X=2880
F1_X=3600

echo "=== HomeTeam QA Screenshots: $VERSION ==="

# Unlock keychain
ssh "$QA_HOST" "security unlock-keychain -p 'anthropic' ~/Library/Keychains/login.keychain-db"

# Capture LIT mode (hide all windows + activate Finder -> desktop gets focus)
echo "Capturing lit mode..."
ssh "$QA_HOST" 'osascript -e "tell application \"System Events\" to set visible of every process whose visible is true to false" -e "tell application \"Finder\" to activate"'
sleep 2
ssh "$QA_HOST" "screencapture -x /tmp/ht_lit.png"

# Capture DIM mode (Terminal in foreground)
echo "Capturing dim mode..."
ssh "$QA_HOST" 'osascript -e "tell application \"Terminal\" to activate"'
sleep 2
ssh "$QA_HOST" "screencapture -x /tmp/ht_dim.png"

# Crop individual widgets
echo "Cropping widgets..."
ssh "$QA_HOST" "
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $NHL_X /tmp/ht_lit.png --out /tmp/ht_nhl_lit.png 2>/dev/null
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $MOTOGP_X /tmp/ht_lit.png --out /tmp/ht_motogp_lit.png 2>/dev/null
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $F1_X /tmp/ht_lit.png --out /tmp/ht_f1_lit.png 2>/dev/null
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $NHL_X /tmp/ht_dim.png --out /tmp/ht_nhl_dim.png 2>/dev/null
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $MOTOGP_X /tmp/ht_dim.png --out /tmp/ht_motogp_dim.png 2>/dev/null
sips -c $CROP_H $CROP_W --cropOffset $CROP_Y $F1_X /tmp/ht_dim.png --out /tmp/ht_f1_dim.png 2>/dev/null
"

# Download to local screenshots dir
mkdir -p "$SCREENSHOTS_DIR"
echo "Downloading..."
scp "$QA_HOST:/tmp/ht_nhl_lit.png" "$SCREENSHOTS_DIR/${VERSION}_nhl_lit.png"
scp "$QA_HOST:/tmp/ht_motogp_lit.png" "$SCREENSHOTS_DIR/${VERSION}_motogp_lit.png"
scp "$QA_HOST:/tmp/ht_f1_lit.png" "$SCREENSHOTS_DIR/${VERSION}_f1_lit.png"
scp "$QA_HOST:/tmp/ht_nhl_dim.png" "$SCREENSHOTS_DIR/${VERSION}_nhl_dim.png"
scp "$QA_HOST:/tmp/ht_motogp_dim.png" "$SCREENSHOTS_DIR/${VERSION}_motogp_dim.png"
scp "$QA_HOST:/tmp/ht_f1_dim.png" "$SCREENSHOTS_DIR/${VERSION}_f1_dim.png"

# Scale to 1800px max width
for f in "$SCREENSHOTS_DIR/${VERSION}_"*.png; do
  pw=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
  if [ "$pw" -gt 1800 ]; then
    sips --resampleWidth 1800 "$f" --out "$f" 2>/dev/null
  fi
done

# Clean up remote temp files
ssh "$QA_HOST" "rm -f /tmp/ht_lit.png /tmp/ht_dim.png /tmp/ht_nhl_*.png /tmp/ht_motogp_*.png /tmp/ht_f1_*.png"

# Prune to latest 10 builds
# Extract unique version prefixes, sort by file modification time (newest first)
cd "$SCREENSHOTS_DIR"
ls -t *_nhl_lit.png 2>/dev/null | sed 's/_nhl_lit\.png$//' | tail -n +11 | while read old_ver; do
  rm -f "${old_ver}_"*.png
  echo "Pruned $old_ver"
done

# Regenerate review.html
echo "Generating review.html..."
python3 << PYEOF
import os, re
from pathlib import Path

screenshots_dir = Path("$SCREENSHOTS_DIR")
qa_dir = Path("$QA_DIR")

# Find all builds by looking for *_nhl_lit.png files, sorted newest first
builds = []
for f in sorted(screenshots_dir.glob("*_nhl_lit.png"), key=lambda p: p.stat().st_mtime, reverse=True):
    ver = f.name.replace("_nhl_lit.png", "")
    # Get timestamp from file mtime
    import datetime
    mtime = datetime.datetime.fromtimestamp(f.stat().st_mtime)
    ts = mtime.strftime("%Y-%m-%d %H:%M")
    builds.append((ver, ts))

sports = [
    ("NHL", "nhl"),
    ("MotoGP", "motogp"),
    ("F1", "f1"),
]

html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>HomeTeam — Widget QA Screenshots</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; background: #1a1a1a; color: #e0e0e0; margin: 0; padding: 40px; }
  h1 { text-align: center; font-weight: 600; margin-bottom: 8px; }
  .subtitle { text-align: center; color: #888; font-size: 13px; margin-bottom: 40px; }
  .build { max-width: 1400px; margin: 0 auto 60px; }
  .build-header { display: flex; align-items: baseline; gap: 16px; margin-bottom: 20px; padding-bottom: 12px; border-bottom: 1px solid #333; }
  .build-header h2 { margin: 0; font-size: 22px; }
  .date { color: #888; font-size: 13px; }
  .sport-label { font-size: 11px; font-weight: 600; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin: 16px 0 8px; }
  .sport-label:first-child { margin-top: 0; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 20px; }
  .card { background: #252525; border-radius: 12px; overflow: hidden; }
  .card h3 { font-size: 12px; font-weight: 600; padding: 14px 18px 10px; margin: 0; color: #888; text-transform: uppercase; letter-spacing: 0.5px; }
  .card img { width: 100%; display: block; }
  .empty { text-align: center; color: #555; padding: 80px 0; font-size: 14px; }
</style>
</head>
<body>
  <h1>HomeTeam — Widget QA Screenshots</h1>
  <p class="subtitle">Dim and lit mode captures from QA Mac. 6 images per build (NHL, F1, MotoGP x 2 modes). Latest 10 builds retained.</p>
"""

if not builds:
    html += '  <div class="empty">No builds captured yet.</div>\\n'
else:
    for ver, ts in builds:
        html += f'''
  <div class="build">
    <div class="build-header">
      <h2>{ver}</h2>
      <span class="date">Captured: {ts}</span>
    </div>
'''
        for sport_name, sport_key in sports:
            lit_file = f"screenshots/{ver}_{sport_key}_lit.png"
            dim_file = f"screenshots/{ver}_{sport_key}_dim.png"
            html += f'    <div class="sport-label">{sport_name}</div>\\n'
            html += f'    <div class="grid">\\n'
            html += f'      <div class="card">\\n'
            html += f'        <h3>{sport_name} — Lit Mode</h3>\\n'
            html += f'        <img src="{lit_file}">\\n'
            html += f'      </div>\\n'
            html += f'      <div class="card">\\n'
            html += f'        <h3>{sport_name} — Dim Mode</h3>\\n'
            html += f'        <img src="{dim_file}">\\n'
            html += f'      </div>\\n'
            html += f'    </div>\\n'
        html += '  </div>\\n'

# Mockups (persist indefinitely — never purge). Each *.html file in qa/mockups/
# is embedded as an iframe below the build screenshots.
mockup_dir = qa_dir / "mockups"
if mockup_dir.exists():
    for mockup in sorted(mockup_dir.glob("*.html")):
        name = mockup.stem.replace("-", " ").title()
        html += f'''
  <div class="build">
    <div class="build-header">
      <h2>Mockup: {name}</h2>
    </div>
    <iframe src="mockups/{mockup.name}" style="width:100%;height:700px;border:1px solid #333;border-radius:12px;background:#fff;"></iframe>
  </div>
'''

html += """
</body>
</html>
"""

(qa_dir / "review.html").write_text(html)
print(f"Generated review.html with {len(builds)} build(s)")
PYEOF

echo "=== Done: $VERSION ==="
echo "Screenshots: $SCREENSHOTS_DIR/${VERSION}_*.png"
echo "Review: file://$QA_DIR/review.html"
