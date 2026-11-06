# Card tools

Tools for getting the physical cards into `cards/cards.json`.

## Catalog editor with scan dialog

```sh
sudo pacman -Syu tesseract tesseract-data-deu      # Debian/Ubuntu: tesseract-ocr tesseract-ocr-deu
./card-editor.sh                                   # opens http://127.0.0.1:8765/
```

The script creates `.venv` on first run and installs `tools/ocr/requirements.txt`; extra arguments go to
`tools/server.py` (`--port`, `--catalog`, `--scans`, `--lang`, `--no-browser`).

`tools/server.py` serves the editor page, reads/writes `cards/cards.json`, stores scanned photos in `scans/` and
runs the German OCR. It only listens on localhost and rejects requests from other origins.

**Scan card** (needs the server) is a three-step flow:
1. *Back*: show the QR side. The server reads the code (OpenCV) and the dialog beeps.
2. *Front*: turn the card over, **fill the dashed frame with the card** and hold it still. The photo is taken
   automatically (or press Space / *Take photo now*), cropped to the frame plus a margin, and read by tesseract.
3. *Check*: the edit form opens with the photo, title and effect, and the deck and level of the card scanned
   before (scanning goes deck by deck). Correct them, check the level, add symbols, press
   *Add card & scan next*. The card is saved to the file right away and the camera is ready for the next one.
   *Retake photo* goes back to step 2 for the same card, *Discard card* forgets it, *Stop scanning* ends the session.

The server finds the card in the photo by its edges and straightens it, so the card may be a little off the frame
or tilted, but all four edges have to be in the photo, against a background that is lighter or darker than the
card's border. The title band and the text panel are then read at their fixed places on the card
(`tools/ocr/ocr.py`). Boxes drawn on the photo in step 3 replace that for the following cards until *Reset boxes*.
Light the card from the front and avoid glare. If the effect text is unclear it is left empty rather than filled
with junk; type it from the photo. Small icons inside the effect text are not recognised.
Scanned cards only get German texts. The game shows German where a translation is missing.

**Editing**: search, filter (*Without symbols* finds scanned cards that still need symbols), sort, add, edit,
delete. Problems against the schema (bad QR, duplicate QR, missing German title…) are listed at the top, and
the server refuses to save until they are fixed. Save with Ctrl+S.

The camera works on `http://127.0.0.1` (a secure context), not on a plain LAN address.

`tools/editor/catalog_editor.html` can also be opened directly as a file (no server, no scanning): Chrome/Edge
save in place, Firefox downloads the file. In that mode **Scans folder…** shows photos while editing.

Tests: `cd tools/ocr && python -m unittest` (text handling, and OCR of the card photos in `tools/ocr/fixtures`
when tesseract is installed), `cd tools && python -m unittest` (catalog checks).
