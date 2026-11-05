"""OCR of the card front with tesseract, used by the editor server.

The input is a photo of just the card (the scan dialog crops it to its guide frame), so the title and the
effect are read from fixed areas: the title bar at the top and the text box in the lower part. Webcam photos
are soft and the light text sits on a dark panel, so each area is read with a few preprocessing variants and
the result with the best confidence wins."""

import os
import re
from concurrent.futures import ThreadPoolExecutor

import cv2

from card_text import Word, group_lines, join_paragraphs, clean

# x0, y0, x1, y1 as fractions of the card photo. The photo is only roughly aligned with the card, and a
# crop that clips the border or the text reads far worse, so the title is tried at a few vertical offsets.
TITLE_AREAS = [(0.10, y0, 0.90, y1) for y0, y1 in ((0.0, 0.12), (0.015, 0.11), (0.03, 0.12), (0.0, 0.09))]
EFFECT_AREAS = [(0.06, 0.60, 0.94, 0.96)]
MIN_EFFECT_CONFIDENCE = 45  # below this the effect is more likely noise than text


def _variants(grey, scale):
    """Preprocessed copies of a grey crop: contrast-limited equalisation with and without sharpening."""
    g = cv2.resize(grey, None, fx=scale, fy=scale, interpolation=cv2.INTER_LANCZOS4)
    eq = cv2.createCLAHE(2.0, (8, 8)).apply(g)
    blur = cv2.GaussianBlur(eq, (0, 0), 2)
    sharp = cv2.addWeighted(eq, 1.8, blur, -0.8, 0)
    return [eq, sharp]


def _words(image, lang, psm):
    import pytesseract

    d = pytesseract.image_to_data(image, lang=lang, config=f"--psm {psm}", output_type=pytesseract.Output.DICT)
    return [Word(d["text"][i], d["left"][i], d["top"][i], d["width"][i], d["height"][i], float(d["conf"][i]),
                 d["block_num"][i], d["par_num"][i], d["line_num"][i]) for i in range(len(d["text"]))]


def _read_area(card_grey, areas, lang, psm, scales, min_letters):
    """Best reading of one text area as (lines, mean confidence), trying every area crop and variant."""
    h, w = card_grey.shape
    # the areas are the same size for every card, so scale by the card's pixel size rather than the crop's
    scale_base = 1000 / w
    jobs = []
    for x0, y0, x1, y1 in areas:
        crop = card_grey[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]
        jobs += [image for s in scales for image in _variants(crop, s * scale_base)]

    def read(image):
        return [wd for wd in _words(image, lang, psm) if wd.conf >= 30 and sum(c.isalpha() for c in wd.text) >= min_letters]

    best = ([], 0.0, 0.0)
    with ThreadPoolExecutor(os.cpu_count() or 2) as pool:  # tesseract runs as separate processes
        for words in pool.map(read, jobs):
            score = sum(wd.conf for wd in words)  # favours the reading that recognised more text
            if words and score > best[2]:
                best = (group_lines(words, 0), score / len(words), score)
    return best[0], best[1]


def read_front(image, lang, title_box=None, effect_box=None):
    """(title, effect, effect_ok) from a photo of the card front. The boxes are (x0, y0, x1, y1) fractions of
    the photo drawn by the user; without one the default areas are tried. effect_ok is False when the effect
    came out too unclear to be worth keeping (only judged for the default area: a box drawn by the user is
    trusted, and a card may simply have no effect)."""
    grey = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    title_lines, _ = _read_area(grey, [title_box] if title_box else TITLE_AREAS, lang, 7, (1.0, 1.5), 3)
    # decoration next to the title (the corner ornaments) comes out as stray characters
    title = clean(re.sub(r"^[\W_]+|[\W_]+$", "", " ".join(l.text for l in title_lines)))
    effect_lines, confidence = _read_area(grey, [effect_box] if effect_box else EFFECT_AREAS, lang, 6, (1.0, 1.5), 2)
    effect = join_paragraphs(effect_lines)
    if effect_box:
        return title, effect, bool(effect)
    ok = confidence >= MIN_EFFECT_CONFIDENCE and len(effect.split()) >= 3
    return title, effect if ok else "", ok
