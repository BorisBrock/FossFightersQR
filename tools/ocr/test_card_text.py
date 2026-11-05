import unittest

from card_text import *


def w(text, left, top, h, block=1, par=1, line=1, conf=90):
    return Word(text, left, top, 50, h, conf, block, par, line)


class CardTextTest(unittest.TestCase):
    def test_split(self):
        words = [w("Feuer", 10, 10, 40), w("ball", 80, 10, 40),
                 w("Füge", 10, 100, 20, 2, 1, 1), w("einem", 80, 100, 20, 2, 1, 1),
                 w("Ziel", 10, 125, 20, 2, 1, 2), w("Schaden", 80, 125, 20, 2, 1, 2),
                 w("Brennt", 10, 200, 20, 2, 2, 1), w("es", 80, 200, 20, 2, 2, 1),
                 w("~", 10, 300, 20, 3, 1, 1), w("xx", 10, 330, 20, 3, 1, 2, conf=5)]
        title, effect = split_title_effect(group_lines(words))
        self.assertEqual(title, "Feuer ball")
        self.assertEqual(effect, "Füge einem Ziel Schaden\nBrennt es")

    def test_empty(self):
        self.assertEqual(split_title_effect([]), ("", ""))


if __name__ == "__main__":
    unittest.main()
