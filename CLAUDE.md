# FossFightersQR

Godot 4 project. Docs are in `docs/`; the card catalog and its abilities are described in `docs/cards.md`.

## Running the tests

**Which tests to run after a change:**

- By default, run only the suites that cover what changed (e.g. `test_fight.gd` for fight logic), or `tests/run.sh`
  (all fast headless suites, ~1 min, one line per suite).
- Do **not** run the windowed GUI tests (`test_game`, `test_onboarding`, or `tests/run.sh gui`/`all`) as a routine
  check. They are slow. Run them only when the change touches what they cover (camera, scanning, decoder, main
  scene, onboarding flow), or when the user asks. If they look relevant but you are unsure, say so instead of running them.
- Pure docs, messages, art or sound changes need no test run unless they change a file a test loads.
- Don't rerun a suite that has already passed for the same code.

Most tests run headless, but **`test_game` and `test_onboarding` need a window**: they send a fake camera's frames
through the real GPU to the decoder. Run with `--headless`, they get no frames (`frames_submitted: 0`), and every scan
check fails (16 and 7 failures). That is not a bug in the code. Always run them without `--headless`:

    godot --headless res://tests/check_project.tscn   # every script and scene compiles and loads
    godot --headless -s tests/test_decoder.gd
    godot --headless -s tests/test_cards.gd
    godot --headless -s tests/test_party.gd
    godot --headless -s tests/test_fight.gd
    godot --headless -s tests/test_messages.gd
    godot --headless res://tests/test_settings.tscn
    godot --headless res://tests/test_bosses.tscn
    godot --headless res://tests/test_boss_fight.tscn
    godot --disable-vsync res://tests/test_game.tscn        # NOT headless: opens a window
    godot --disable-vsync res://tests/test_onboarding.tscn  # NOT headless: opens a window

`--disable-vsync` matters: an unwatched window can be throttled to ~1 fps, and then the timing checks fail.

Balance simulator (not a test; see `docs/balance.md`):

    godot --headless -s tools/balance/simulate.gd -- --games 200

Catalog and tool checks:

    .venv/bin/python tools/validate_catalog.py
    cd tools && ../.venv/bin/python -m unittest

`tests/test_fight.gd` has `EXPECTED_CHECKS`: raise it when adding checks.
