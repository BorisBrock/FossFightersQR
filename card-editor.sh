#!/usr/bin/env bash
# Starts the card catalog editor (http://127.0.0.1:8765/). Extra arguments go to tools/server.py.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v tesseract >/dev/null; then
    echo "tesseract not found, scanning will not work. Arch: sudo pacman -Syu tesseract tesseract-data-deu" >&2
elif ! tesseract --list-langs 2>/dev/null | grep -qx deu; then
    echo "tesseract has no German data, scanning will not work. Arch: sudo pacman -S tesseract-data-deu" >&2
fi

if [ ! -x .venv/bin/python ]; then
    python3 -m venv .venv
fi
if ! .venv/bin/python -c "import cv2, jsonschema, numpy, pytesseract; cv2.wechat_qrcode_WeChatQRCode" 2>/dev/null; then
    # plain opencv-python would shadow opencv-contrib-python, which has the better QR detector
    .venv/bin/pip uninstall -q -y opencv-python opencv-python-headless 2>/dev/null || true
    .venv/bin/pip install -q -r tools/ocr/requirements.txt
fi

exec .venv/bin/python tools/server.py "$@"
