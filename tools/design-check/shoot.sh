#!/bin/zsh
# Screenshot one artboard at the simulator's scale, so the pair can be laid
# side by side without resizing.
#
#   tools/design-check/shoot.sh Main            -> .design/shots/Main-design.png
#   tools/design-check/shoot.sh MainDark 1500   (height in points; default
#                                                from canvas.json)
#
# Needs the design-artboards server (http://localhost:8765) running, and
# Google Chrome or Microsoft Edge installed for the headless render.
set -euo pipefail
cd "$(dirname "$0")/../.."
name="$1"
height="${2:-}"
if [[ -z "$height" ]]; then
  height=$(python3 -c "import json,sys;b=json.load(open('design/canvas/canvas.json'))['boards'].get('$name.dc.html');print(b['h'] if b else 844)")
fi
width=$(python3 -c "import json;b=json.load(open('design/canvas/canvas.json'))['boards'].get('$name.dc.html');print(b['w'] if b else 390)")
browser=""
for b in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
  [[ -x "$b" ]] && browser="$b" && break
done
[[ -z "$browser" ]] && { echo "no Chrome or Edge for the headless render" >&2; exit 1; }
mkdir -p .design/shots
cp -f tools/design-check/support.js design/canvas/support.js
out=".design/shots/${name}-design.png"
"$browser" --headless=new --hide-scrollbars --force-device-scale-factor=3 \
  --window-size="${width},${height}" --virtual-time-budget=3000 \
  --screenshot="$PWD/$out" "http://localhost:8765/${name}.dc.html" >/dev/null 2>&1
echo "$out (${width}x${height} pt at 3x)"
