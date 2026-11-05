"""Pure helper for the editor server: turns tesseract word boxes into the title and effect of a card.
Kept free of OCR dependencies so it can be tested on its own."""

import re
from dataclasses import dataclass
from statistics import median


@dataclass
class Word:
    text: str
    left: int
    top: int
    width: int
    height: int
    conf: float
    block: int
    par: int
    line: int


@dataclass
class Line:
    text: str
    top: int
    bottom: int
    par_key: tuple

    @property
    def height(self):
        return self.bottom - self.top


def group_lines(words, min_conf=30):
    """Merges OCR words into lines, dropping low-confidence noise (card art produces a lot of it)."""
    by_line = {}
    for w in words:
        if not w.text.strip() or w.conf < min_conf:
            continue
        by_line.setdefault((w.block, w.par, w.line), []).append(w)
    lines = []
    for key, ws in by_line.items():
        ws.sort(key=lambda w: w.left)
        text = " ".join(w.text.strip() for w in ws)
        # a "line" with no letters is a border or a symbol, not text
        if sum(c.isalpha() for c in text) < 2:
            continue
        # word box heights vary with ascenders, so use the median
        top = int(median(w.top for w in ws))
        bottom = int(median(w.top + w.height for w in ws))
        lines.append(Line(text, top, bottom, key[:2]))
    lines.sort(key=lambda l: l.top)
    return lines


def split_title_effect(lines):
    """The title is the leading run of lines with the largest text; everything below is the effect.
    Lines of one paragraph are joined with spaces, paragraphs with a newline."""
    if not lines:
        return "", ""
    reference = max(l.height for l in lines[:3])
    title_lines = [lines[0]]
    for line in lines[1:]:
        gap = line.top - title_lines[-1].bottom
        if line.height >= 0.8 * reference and gap < 1.0 * reference and len(title_lines) < 2:
            title_lines.append(line)
        else:
            break
    title = " ".join(l.text for l in title_lines)
    rest = lines[len(title_lines):]
    return clean(title), join_paragraphs(rest)


def join_paragraphs(lines):
    paragraphs, last_key, last_bottom = [], None, None
    for line in lines:
        new_par = last_key is None or line.par_key != last_key
        if not new_par and last_bottom is not None and line.top - last_bottom > 1.2 * line.height:
            new_par = True
        if new_par:
            paragraphs.append([line.text])
        else:
            paragraphs[-1].append(line.text)
        last_key, last_bottom = line.par_key, line.bottom
    return "\n".join(clean(" ".join(p)) for p in paragraphs)


def clean(text):
    text = text.replace("|", "I")
    return re.sub(r"[ \t]+", " ", text).strip()
