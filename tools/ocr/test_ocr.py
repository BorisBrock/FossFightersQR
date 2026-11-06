"""OCR of webcam photos of real cards (tools/ocr/fixtures), as the editor sends them: the dashed guide frame with
its margin, JPEG at 1080p. Skipped when OpenCV, pytesseract or tesseract's German data are missing."""

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


def normalised(text):
    return re.sub(r"\s+", " ", text).strip()


@unittest.skipUnless(HAVE_OCR, "needs opencv, pytesseract and tesseract with German data")
class OcrTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from ocr import read_front

        with open(os.path.join(FIXTURES, "expected.json"), encoding="utf-8") as f:
            cls.expected = json.load(f)
        cls.read = {name: read_front(cv2.imread(os.path.join(FIXTURES, name)), "deu") for name in cls.expected}

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

    def test_no_effect_from_qr_side(self):
        from ocr import read_front

        for path in sorted(glob.glob(os.path.join(QR_FIXTURES, "*.png"))):
            with self.subTest(os.path.basename(path)):
                _, effect, ok = read_front(cv2.imread(path), "deu")
                self.assertEqual((effect, ok), ("", False))

    def test_user_boxes(self):
        # boxes drawn around the text on the photo (the card lies at x 0.20-0.93, y 0.04-0.87) replace the found card
        from ocr import read_front

        image = cv2.imread(os.path.join(FIXTURES, "01_omas_helm.jpg"))
        title, effect, ok = read_front(image, "deu", (0.25, 0.04, 0.88, 0.12), (0.28, 0.57, 0.85, 0.79))
        self.assertEqual(title, "Omas Helm")
        self.assertEqual(normalised(effect), self.expected["01_omas_helm.jpg"]["effect"])


if __name__ == "__main__":
    unittest.main()
