"""OCR of the card front with tesseract, used by the editor server.

The card is located in the photo and straightened (card_finder), so the title and the effect are read from
fixed areas of the card: the title band at the top and the text panel in the lower part. The text on the
cards is light on a darker background, which tesseract reads badly as it is, so every area is turned into
clean black text on white first: the brightest colour channel separates the cream text from the coloured
title bands, a top-hat filter removes the shading of the text panel, and blobs touching the edge of the area
(the band's torn paper edge, ornaments) are dropped. If no card is found, the photo is taken to be the card."""

import re
from concurrent.futures import ThreadPoolExecutor

import cv2
import numpy as np

from card_finder import find_card, straighten
from card_text import Word, group_lines, join_paragraphs, clean

CARD_WIDTH = 1200  # pixels of the straightened card; the scales and the kernel below are tuned for this
# x0, y0, x1, y1 as fractions of the card
TITLE_AREA = (0.06, 0.0, 0.94, 0.09)
EFFECT_AREA = (0.11, 0.635, 0.89, 0.895)
TITLE_SCALE = 0.5  # the title letters are big, tesseract reads them better scaled down
EFFECT_SCALE = 1.4  # and the effect letters a bit bigger
EFFECT_BACKGROUND_KERNEL = 25  # wider than a letter stroke, narrower than the shading of the panel
MIN_WORD_CONFIDENCE = 20  # the preprocessing leaves little noise, so even unsure words are mostly right
# An effect is only kept if at least one word of 4 letters or more was read with this confidence: words of the
# effect text come out at 85-93, noise read from card art or QR codes never got there.
CLEAR_WORD_CONFIDENCE = 80


def _drop_border_blobs(binary):
    """Removes the white blobs that touch the edge of the image: the text lies inside the area."""
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    h, w = binary.shape
    x, y, bw, bh, area = stats.T
    keep = (x > 0) & (y > 0) & (x + bw < w) & (y + bh < h) & (area > 6)
    keep[0] = False  # the background
    return np.where(keep[labels], 255, 0).astype(np.uint8)


def text_image(crop, scale, background_kernel=0):
    """Black text on white from a crop with light text, scaled by the given factor."""
    bright = crop.min(axis=2) if crop.ndim == 3 else crop  # cream text is bright in every channel
    bright = cv2.GaussianBlur(bright, (3, 3), 0)  # JPEG noise
    if background_kernel:
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (background_kernel, background_kernel))
        bright = cv2.morphologyEx(bright, cv2.MORPH_TOPHAT, kernel)
    bright = cv2.resize(bright, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC)
    otsu, _ = cv2.threshold(bright, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # with little text in the area Otsu's threshold can drop into the noise of the background
    floor = 0.4 * np.percentile(bright, 99.5)
    _, binary = cv2.threshold(bright, max(otsu, floor), 255, cv2.THRESH_BINARY)
    # tesseract wants dark text with a margin of background around it
    return cv2.copyMakeBorder(255 - _drop_border_blobs(binary), 20, 20, 20, 20, cv2.BORDER_CONSTANT, value=255)


def _words(image, lang, psm):
    import pytesseract

    d = pytesseract.image_to_data(image, lang=lang, config=f"--psm {psm}", output_type=pytesseract.Output.DICT)
    return [Word(d["text"][i], d["left"][i], d["top"][i], d["width"][i], d["height"][i], float(d["conf"][i]),
                 d["block_num"][i], d["par_num"][i], d["line_num"][i]) for i in range(len(d["text"]))]


def _crop(image, box):
    h, w = image.shape[:2]
    x0, y0, x1, y1 = box
    return image[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]


def _read(crop, lang, psm, scale, background_kernel=0):
    """Reading of a crop as (lines, whether it contains at least one clearly recognised word)."""
    words = _words(text_image(crop, scale, background_kernel), lang, psm)
    # stray marks come out as words without letters or digits
    words = [w for w in words if w.conf >= MIN_WORD_CONFIDENCE and any(c.isalnum() for c in w.text)]
    clear = any(w.conf >= CLEAR_WORD_CONFIDENCE and sum(c.isalpha() for c in w.text) >= 4 for w in words)
    return group_lines(words, 0), clear


def read_front(image, lang, title_box=None, effect_box=None):
    """(title, effect, effect_ok) from a photo of the card front. The boxes are (x0, y0, x1, y1) fractions of
    the photo drawn by the user; without one the area of the found card is read. effect_ok is False when the
    effect came out too unclear to be worth keeping (only judged without a box: a box drawn by the user is
    trusted, and a card may simply have no effect)."""
    corners = find_card(image)
    if corners is not None:
        card = straighten(image, corners, CARD_WIDTH)
        card_width = (np.linalg.norm(corners[1] - corners[0]) + np.linalg.norm(corners[2] - corners[3])) / 2
    else:
        card = cv2.resize(image, (CARD_WIDTH, round(image.shape[0] * CARD_WIDTH / image.shape[1])))
        card_width = image.shape[1]

    def area(box, default):
        if not box:
            return _crop(card, default)
        # a box drawn by the user is cut from the photo, and scaled as if it was cut from the straightened card
        s = CARD_WIDTH / card_width
        return cv2.resize(_crop(image, box), None, fx=s, fy=s, interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)

    with ThreadPoolExecutor(2) as pool:  # tesseract runs as separate processes
        title_job = pool.submit(_read, area(title_box, TITLE_AREA), lang, 7, TITLE_SCALE)
        effect_job = pool.submit(_read, area(effect_box, EFFECT_AREA), lang, 6, EFFECT_SCALE, EFFECT_BACKGROUND_KERNEL)
        title_lines, _ = title_job.result()
        effect_lines, clear = effect_job.result()
    # decoration next to the title comes out as stray characters
    title = clean(re.sub(r"^[\W_]+|[\W_]+$", "", " ".join(l.text for l in title_lines)))
    effect = join_paragraphs(effect_lines)
    if effect_box:
        return title, effect, bool(effect)
    ok = bool(effect) and clear
    return title, effect if ok else "", ok
