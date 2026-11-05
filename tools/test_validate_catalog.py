import json
import unittest

from validate_catalog import CARDS_DIR, find_problems


def catalog(*cards):
    return json.dumps({"schema_version": 2, "cards": list(cards)})


CARD = {"qr": "A", "deck": "core"}


class FindProblems(unittest.TestCase):
    def test_the_real_catalog_is_valid(self):
        self.assertEqual(find_problems((CARDS_DIR / "cards.json").read_text(encoding="utf-8")), [])

    def test_accepts_a_card_with_only_the_required_fields(self):
        self.assertEqual(find_problems(catalog(CARD)), [])

    def test_keeps_a_text_ending_in_a_quote(self):
        self.assertEqual(find_problems(catalog({**CARD, "effect": {"de": 'one\nsays "hi"'}})), [])

    def test_rejects_broken_json(self):
        self.assertIn("not valid JSON", find_problems('{"cards": [')[0])

    def test_rejects_a_repeated_key(self):
        self.assertIn("key used twice: qr", find_problems('{"schema_version": 2, "cards": [{"qr": "A", "qr": "B", "deck": "core"}]}')[0])

    def test_rejects_a_duplicate_qr_code(self):
        self.assertEqual(find_problems(catalog(CARD, {**CARD, "deck": "expansion1"})), ["QR code used by two cards: A"])

    def test_rejects_a_card_without_deck(self):
        self.assertIn("'deck' is a required property", find_problems(catalog({"qr": "A"}))[0])

    def test_rejects_text_without_german(self):
        self.assertIn("'de' is a required property", find_problems(catalog({**CARD, "title": {"en": "x"}}))[0])

    def test_rejects_another_schema_version(self):
        self.assertTrue(find_problems(json.dumps({"schema_version": 1, "cards": []})))


if __name__ == "__main__":
    unittest.main()
