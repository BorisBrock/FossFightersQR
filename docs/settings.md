# Settings

The gear button at the top left opens the settings dialog, both in the onboarding and in the game. It has an on/off
toggle and a volume slider for music and for sound effects, and the choice of language: *System* (the default), which
follows the device, *Deutsch* or *English*.

- Changes count at once. Moving the sound effects slider or turning them on plays a sample sound.
- A new language shows at once in the dialog and behind it, and also applies to the text of the cards. A device in
  any other language gets German, the language of the printed cards.
- The dialog closes with *Done*, a tap next to it, Escape or the back button of a phone. Each of these saves.
- The scanner keeps running behind the dialog.

## How it fits together

- `scripts/settings.gd` is the autoload `Settings`. It holds the values, applies them to the audio buses and keeps them
  in `user://settings.cfg`. A missing or damaged value falls back to its default.
- `scripts/settings_button.gd` makes any button open the dialog (`settings_dialog.tscn`), so each scene can style its
  own button.
- `default_bus_layout.tres` has the buses `Music` and `SFX`. **Every new sound needs `bus = &"SFX"`**, or the settings
  will not reach it. `tests/test_settings.gd` checks the existing ones.
- Music is the player's `volume_db` in `music.tscn` plus the bus. The default of 50 % gives -12 dB and the player
  another -8 dB, so -20 dB in total, which leaves room to turn it up in a loud room.

## Adding text

Each script keeps its text in a `TEXT` dictionary with one entry per language and looks
it up with `CardDatabase.localized(text, TranslationServer.get_locale())`. Whatever is on screen when the language
changes has to be set again on `NOTIFICATION_TRANSLATION_CHANGED`, as `scripts/main.gd` does. That notification also
arrives when a node enters the tree, before it is ready, hence the `is_node_ready()` there.

The one exception are the messages in the fight, which are in files per language, as there will be many of them.
See [Messages](messages.md).

Error details from `CardDatabase.error` are for whoever edits the catalog and stay in English.

## Adding a setting

Add the value with a default to `scripts/settings.gd` (`load_file` and `save`), and its control to
`settings_dialog.tscn`. Controls are styled in `assets/onboarding/theme.tres`.
