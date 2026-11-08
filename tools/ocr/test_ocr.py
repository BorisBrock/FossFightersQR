"""OCR of webcam photos of real cards (tools/ocr/fixtures), as the editor sends them: the dashed guide frame with
its margin, JPEG at 1080p. Skipped when OpenCV, pytesseract or tesseract's German data are missing.

The photos show copyrighted cards, so they are not in the repository (see .gitignore): put them into
tools/ocr/fixtures under the names in expected.json to run the photo tests; without them those are skipped."""

import difflib
import glob
import json
import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
QR_FIXTURES = os.path.join(HERE, "..", "..", "tests", "fixtures")

try:
    import cv2
    import pytesseract

    HAVE_OCR = "deu" in pytesseract.get_languages()
except Exception:  # missing package or tesseract binary
    HAVE_OCR = False


with open(os.path.join(FIXTURES, "expected.json"), encoding="utf-8") as f:
    EXPECTED = json.load(f)
HAVE_PHOTOS = all(os.path.exists(os.path.join(FIXTURES, name)) for name in EXPECTED)


def normalised(text):
    return re.sub(r"\s+", " ", text).strip()


@unittest.skipUnless(HAVE_OCR, "needs opencv, pytesseract and tesseract with German data")
class QrSideTest(unittest.TestCase):
    def test_no_effect_from_qr_side(self):
        from ocr import read_front

        for path in sorted(glob.glob(os.path.join(QR_FIXTURES, "*.png"))):
            with self.subTest(os.path.basename(path)):
                _, effect, ok = read_front(cv2.imread(path), "deu")[:3]
                self.assertEqual((effect, ok), ("", False))


@unittest.skipUnless(HAVE_OCR, "needs opencv, pytesseract and tesseract with German data")
@unittest.skipUnless(HAVE_PHOTOS, "needs the card photos in tools/ocr/fixtures (not in the repository)")
class OcrTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from ocr import read_front

        cls.expected = EXPECTED
        cls.read = {name: read_front(cv2.imread(os.path.join(FIXTURES, name)), "deu")[:3] for name in cls.expected}

    def test_titles(self):
        for name, expected in self.expected.items():
            with self.subTest(name):
                self.assertEqual(self.read[name][0], expected["title"])

    def test_effects(self):
        # an icon inside the text can't come out right, so allow a few characters off
        for name, expected in self.expected.items():
            with self.subTest(name):
                _, effect, ok = self.read[name]
                self.assertTrue(ok)
                similarity = difflib.SequenceMatcher(None, normalised(effect), expected["effect"]).ratio()
                self.assertGreater(similarity, 0.95, effect)

    def test_card_found(self):
        from card_finder import find_card

        for name in self.expected:
            with self.subTest(name):
                self.assertIsNotNone(find_card(cv2.imread(os.path.join(FIXTURES, name))))

    def test_user_boxes(self):
        # boxes drawn around the text on the photo (the card lies at x 0.20-0.93, y 0.04-0.87) replace the found card
        from ocr import read_front

        image = cv2.imread(os.path.join(FIXTURES, "01_omas_helm.jpg"))
        boxes = {"title": (0.25, 0.04, 0.88, 0.12), "effect": (0.28, 0.57, 0.85, 0.79)}
        title, effect, ok, areas, _ = read_front(image, "deu", boxes)
        self.assertEqual(title, "Omas Helm")
        self.assertEqual(normalised(effect), self.expected["01_omas_helm.jpg"]["effect"])
        self.assertEqual(areas, boxes)

    def test_card_boxes_follow_the_card(self):
        # boxes drawn on one photo are kept as fractions of the card, so they still fit when the camera was moved
        import numpy as np
        from ocr import read_front

        image = cv2.imread(os.path.join(FIXTURES, "01_omas_helm.jpg"))
        to_card = np.array(read_front(image, "deu").to_card).reshape(3, 3)
        drawn = {"title": (0.25, 0.04, 0.88, 0.12), "effect": (0.28, 0.57, 0.85, 0.79)}
        card_boxes = {}
        for key, (x0, y0, x1, y1) in drawn.items():
            quad = cv2.perspectiveTransform(np.float32([[[x0, y0], [x1, y0], [x1, y1], [x0, y1]]]), to_card)[0]
            card_boxes[key] = (*quad.min(axis=0).clip(0, 1), *quad.max(axis=0).clip(0, 1))
        # the card smaller and further down in the next photo: the same boxes on the photo would miss the text
        moved = cv2.copyMakeBorder(image, 300, 0, 150, 150, cv2.BORDER_REPLICATE)
        self.assertNotEqual(read_front(moved, "deu", drawn).title, "Omas Helm")
        title, effect, ok, areas, _ = read_front(moved, "deu", card_boxes=card_boxes)
        self.assertEqual(title, "Omas Helm")
        expected = self.expected["01_omas_helm.jpg"]["effect"]
        self.assertGreater(difflib.SequenceMatcher(None, normalised(effect), expected).ratio(), 0.95, effect)
        self.assertTrue(ok)

if __name__ == "__main__":
    unittest.main()
