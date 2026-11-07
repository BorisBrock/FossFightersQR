#!/usr/bin/env python3
"""Checks a card catalog against cards/cards.schema.json, plus what the schema cannot express: unique QR codes,
unique JSON keys, and that every card whose symbols cannot say what it does has an ability that exists.

    python tools/validate_catalog.py [file]       # default: cards/cards.json
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

import jsonschema

CARDS_DIR = Path(__file__).resolve().parent.parent / "cards"
ABILITIES_DIR = CARDS_DIR.parent / "scripts" / "abilities"
SCHEMA = json.loads((CARDS_DIR / "cards.schema.json").read_text(encoding="utf-8"))
# Until its real ability is written, a card with the special symbol gets this one (scripts/abilities/todo.gd).
PLACEHOLDER_ABILITY = "todo"
# Symbols whose strength is not used: it is always 0.
NO_STRENGTH = ("special", "remove_from_game")
# The order of a card's fields in cards.json, as the editor writes them.
FIELDS = ["qr", "deck", "race", "hero_class", "level", "title", "symbols", "effect", "ability", "ability_values",
          "uses_per_fight", "tags"]


def _reject_duplicate_keys(pairs):
    # JSON parsers, Godot's included, silently keep the last value of a repeated key
    repeated = [key for key, count in Counter(key for key, _ in pairs).items() if count > 1]
    if repeated:
        raise ValueError(f"key used twice: {repeated[0]}")
    return dict(pairs)


def find_problems(text):
    """Returns what is wrong with the catalog text, empty if it is valid."""
    try:
        document = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except ValueError as e:
        return [f"not valid JSON: {e}"]
    problems = [
        f"{'/'.join(str(part) for part in error.absolute_path) or 'catalog'}: {error.message}"
        for error in jsonschema.Draft7Validator(SCHEMA).iter_errors(document)
    ]
    if isinstance(document, dict) and isinstance(document.get("cards"), list):
        codes = Counter(card["qr"] for card in document["cards"] if isinstance(card, dict) and isinstance(card.get("qr"), str))
        problems += [f"QR code used by two cards: {qr}" for qr, count in codes.items() if count > 1]
        for card in document["cards"]:
            if isinstance(card, dict):
                problems += _ability_problems(card)
    return problems


def _ability_problems(card):
    """A card that does more than its symbols say needs an ability, or the fight silently does too little."""
    name = card.get("qr", "?")
    symbols = [s for s in card.get("symbols", []) if isinstance(s, dict)]
    ability = card.get("ability")
    problems = []
    # A card with the special symbol but no ability is fine: fill_defaults gives it the placeholder, and the fight
    # treats it as one without an effect until its ability is written.
    if not ability:
        if any(s.get("type") in ("attack", "support") and s.get("strength") == 0 for s in symbols):
            problems.append(f"{name}: has an attack or support of strength 0, but no ability to set it")
        if (card.get("race") or card.get("hero_class")) and card.get("effect"):
            problems.append(f"{name}: is a character or class card with an effect, but has no ability")
    elif isinstance(ability, str) and not (ABILITIES_DIR / f"{ability}.gd").is_file():
        problems.append(f"{name}: ability '{ability}' has no script scripts/abilities/{ability}.gd")
    return problems


def fill_defaults(text):
    """The catalog with what the editor fills in itself: strength 0 for symbols that do not use it, and the
    placeholder ability for a card with the special symbol but none. Also what it filled in. The text unchanged if
    nothing was missing or it cannot be read, so that find_problems reports that."""
    filled = []
    try:
        document = json.loads(text)
        cards = document["cards"]
    except (ValueError, TypeError, KeyError):
        return text, filled
    if not isinstance(cards, list):
        return text, filled
    for card in cards:
        if not isinstance(card, dict):
            continue
        symbols = [s for s in card.get("symbols") or [] if isinstance(s, dict)]
        for symbol in symbols:
            if symbol.get("type") in NO_STRENGTH and symbol.get("strength") != 0:
                symbol["strength"] = 0
                filled.append(f"{card.get('qr')}: {symbol['type']} strength 0")
        if not card.get("ability") and any(s.get("type") == "special" for s in symbols):
            card["ability"] = PLACEHOLDER_ABILITY
            filled.append(f"{card.get('qr')}: ability {PLACEHOLDER_ABILITY}")
    return (serialize(document) if filled else text), filled


def serialize(document):
    """Like the editor's serializeCatalog: one line per field keeps the file readable and its diffs small."""
    def one_line(value):
        return re.sub(r"\n\s*", " ", json.dumps(value, ensure_ascii=False, indent=1))

    def present(value):
        return value is not None and (not isinstance(value, (dict, list)) or len(value) > 0)

    entries = []
    for card in document["cards"]:
        fields = [k for k in FIELDS if present(card.get(k))] + [k for k in card if k not in FIELDS]
        entries.append("    {\n" + ",\n".join(f"      {json.dumps(k)}: {one_line(card[k])}" for k in fields) + "\n    }")
    head = "".join(f'  {json.dumps(k)}: {json.dumps(v)},\n' for k, v in document.items() if k != "cards")
    return "{\n" + head + '  "cards": [\n' + ",\n".join(entries) + "\n  ]\n}\n"


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else CARDS_DIR / "cards.json"
    problems = find_problems(path.read_text(encoding="utf-8"))
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
