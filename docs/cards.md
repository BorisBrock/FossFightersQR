# Cards

The cards live in `cards/cards.json`. `cards/cards.schema.json` describes the format, and editors with JSON
support check the file against it through the `$schema` field.

The game reads the file at startup (`CardDatabase`) and turns each entry into a typed `Card`.

The Android export includes the file through `include_filter` in `export_presets.cfg` and leaves out the schema
through `exclude_filter`.

## Checks

The catalog editor's server refuses to save a catalog with problems. To check the file after editing it by hand:

    .venv/bin/python tools/validate_catalog.py

This covers the schema, unique QR codes and repeated JSON keys, which the schema cannot express. The game itself
only checks what it needs to run: fields that are required and have the right type, and unique QR codes.

## On screen

When a code is read, `scripts/main.gd` looks up its exact value in the `qr` fields:

- **Match:** the title, then QR code, deck and level, then the symbols, then the effect.
- **No match:** "Unknown card" and the value of the code.

Text uses the device language, falling back to `de`, the language of the printed cards.

If the file has a problem, the status line at the top says why. If the file cannot be read at all, every card
shows as unknown. A card that is invalid or repeats a QR code is skipped and shows as unknown, the others still
work.

To fill the file from physical cards, see [tools/README.md](../tools/README.md).

`title`, `effect`, `level` and `symbols` are left out for cards that do not have them.

## Character and class cards

A `race` field makes a card a character card, a `hero_class` field makes it a class card. The
[onboarding](onboarding.md) only reacts to these. In the catalog editor, choose it under *Character or class card*.
