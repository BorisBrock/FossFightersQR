# Cards

The cards live in `cards/cards.toml`. `cards/cards.schema.json` describes the format, and editors with TOML
support such as Taplo check the file against it through the `#:schema` line.

The game reads the file at startup (`CardDatabase`). Godot has no TOML support, so `TomlParser` reads it. That
parser handles a subset of TOML and reports anything else as an error, see the top of `scripts/toml_parser.gd`.

The Android export includes the file through `include_filter` in `export_presets.cfg`, because Godot leaves out
files it does not treat as resources.

## On screen

When a code is read, `scripts/main.gd` looks up its exact value in the `qr` fields:

- **Match:** the title, then QR code, deck and level, then the symbols, then the effect. `name` is internal and
  not shown.
- **No match:** "Unknown card" and the value of the code.

Text uses the device language, falling back to `en`.

If the file has a problem, the status line at the top says why, and cards that did not load show as unknown.
Besides syntax errors, this covers a card without `qr` or `title` and two cards with the same QR code, which the
schema cannot express.
