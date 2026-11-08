# FossFightersQR

Godot 4 project. Docs are in `docs/`; the card catalog and its abilities are described in `docs/cards.md`.

## Running the tests

Most tests run headless, but **`test_game` and `test_onboarding` need a window**: they send a fake camera's frames
through the real GPU to the decoder. Run with `--headless`, they get no frames (`frames_submitted: 0`), and every scan
check fails (16 and 7 failures). That is not a bug in the code. Always run them without `--headless`:

    godot --headless -s tests/test_decoder.gd
    godot --headless -s tests/test_cards.gd
    godot --headless -s tests/test_party.gd
    godot --headless -s tests/test_fight.gd
    godot --headless -s tests/test_messages.gd
    godot --headless res://tests/test_settings.tscn
    godot --headless res://tests/test_bosses.tscn
    godot --headless res://tests/test_boss_fight.tscn
    godot res://tests/test_game.tscn          # NOT headless: opens a window
    godot res://tests/test_onboarding.tscn    # NOT headless: opens a window

Catalog and tool checks:

    .venv/bin/python tools/validate_catalog.py
    cd tools && ../.venv/bin/python -m unittest

`tests/test_fight.gd` has `EXPECTED_CHECKS`: raise it when adding checks.
