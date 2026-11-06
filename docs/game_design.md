# Game design

Decisions, rules and hints for further development. Add to this file whenever a decision is made, with the reason if
it is not obvious. Details of single features live in their own files: [onboarding](onboarding.md),
[choosing the boss](bosses.md), [the boss fight](boss_fight.md), [messages](messages.md), [cards](cards.md), [QR scanning](qr_scanning.md).

## Concept

A co-operative card game for 1 to 4 players who sit together at a real table.

- The device lies in the middle of the table, face up, and shows a boss monster the players have to defeat.
- Players draw and play real cards by showing their QR codes to the camera.
- The app applies the effects of the cards.

*Status: the onboarding, choosing the boss and the boss fight with the rules of the base game exist, with three dummy
bosses. The catalog has no playing cards yet. The old scanner test screen (`main.tscn`) is only reached through its
test.*

## Table and screen

- **The whole app is in portrait mode**, facing the player at the table head. All other players watch from the side.
- **7 seats:** the table head at the bottom of the screen, and 3 along each side. The far head stays empty.
- **The screen is a map of the table:** where something appears on screen is where it is on the real table.
- Things that belong to one player are turned to face that player's seat, such as the seat tokens. Things for the
  whole group face the table head.

Seat numbers run clockwise: 0 to 2 down the right side, 3 at the table head, 4 to 6 up the left side. So counting up
gives the order around the table, for example for turns.

## Heroes

A hero has a name, a race, a class and a seat.

- **Races:** halfling, dwarf, elf, troll, goblin inventor, forest dryad.
- **Classes:** paladin, magician, warrior, thief, druid, shaman.
- **German names follow the printed level 1 cards** (`scripts/hero_options.gd`), such as *Wald-Elfe* and *Schurke*, so
  the app calls a hero what the card in the player's hand says.
- **Each race and each class can only be picked once.** With 6 of each and at most 4 heroes, something is always
  free. `Party` enforces this when loading a saved party too.

## Rules for reading cards

- In the hero editor, only character and class cards are accepted. Everything else is ignored, without an error message: cards get
  moved around in view of the camera all the time, and a message for each would be noise.
- The one exception is a card that fits but is not available, such as a taken race. This gets a short explanation,
  because the player did everything right and would otherwise think the scanner has failed.
- A card only counts when it is newly shown. One still in view from before the editor opened has to leave for 2 s first.
- The camera reads a card that stays in view over and over. Anything triggered by a read has to cope with that.

## Decisions

| Decision | Why |
|----------|-----|
| A character card suggests a name, which players can change | A card cannot know a player's name, and typing should not be required to start playing. |
| The setup is remembered between runs | The same group usually plays again, and it then only needs one tap. |
| Everything can be changed at any time | Changing one's mind should cost one tap, and is part of the normal flow at a table. |
| A hero is set up on one page, opened by tapping a seat | Creating and changing a hero are then the same thing, in any order, and there are no steps to walk through. |
| Buttons do not pulse or wiggle | It was more annoying than helpful. Animate a button only as a direct answer to something a player did. |
| Removing a hero asks once more | It is the only action that cannot be undone by choosing again. |
| The game has no camera picture in release builds | Saves power, and the device lies face up, so nobody needs to aim it. |
| Back goes one screen back, also with the back button of a phone | Players expect the phone's back button to go back, not to quit in the middle of setting up. It still quits at the table, the first screen. |
| The difficulty is chosen on the boss's overview | It is chosen once per fight, and right next to the hints that help to judge it. |
| Each boss is a script extending `Boss`, not a data file | Most of a boss is data, but its special rules are code. One file per boss keeps both together, and a boss without special rules is still only data. |
| Back during the fight asks to give up | A fight lasts a while, and a phone's back button is easy to hit by accident. |
| Giving up leads to the boss list | The party is still set up, and the next thing is usually another try. |
| Messages in the fight are closed only by their check mark | Confirming is how the players say they did what the message asks. A tap beside it, or a timer, would let one slip by unread. |
| Message text is in files per language, with an id for each message | Text can be changed and languages added without touching code. The game only knows the ids and the placeholders. |
| The text uses the device language unless changed in the settings, with German as the fallback | German is the language of the printed cards. |
| The heroes' health and cards are not in the app | They are on the table, on the health counters and in the players' hands. The app keeps what only it can know: the boss's health and shields, its attacks and the tokens it gives. |
| Who starts is chosen after the boss has planned its attacks | Knowing the attacks, the players can plan their turns, such as letting a hero with Protection go first. |
| Every phase is announced, also when nothing happens in it | The players always know where in the round they are. |
| Card results that need no doing show on screen, not as a message | Damage and shields can be seen. Messages are for what players have to do (draw, heal, take tokens), so they do not tap through every attack. |
| Boss, cards and hero abilities all are `FightRule`s with the same hooks | A special rule can come from anywhere, and each kind of moment needs only one hook for all of them. |
| A card ability is a script, named by the card, with values from the card | Many cards share an effect with different numbers. The catalog stays data, and only new kinds of effects need code. |

## Hints for development

**Running it**

- `godot --path .` or F5 in the editor runs it on a laptop with the webcam. See
  [Trying it out](onboarding.md#trying-it-out) for aiming and for playing without cards.
- The viewport is 720 x 1280. `window_width_override` only makes the desktop window smaller, so test layouts with
  screenshots at other shapes too: `stretch/aspect="expand"` gives phones and tablets more room, never less.
- Save test data under another name, as `party_path` in `scripts/onboarding.gd` allows. The real party is in
  `user://party.json`, on Linux in `~/.local/share/godot/app_userdata/FossFightersQR/`.

**Tests**

Listed in [QR scanning](qr_scanning.md#testing). Tests that need a camera use `FakeCameraFeed`, which can deliver
frames like Android (`YCbCr`) or like a laptop (`deliver_rgb`). The native Android camera can only be tested on a device.

**Pitfalls we have run into**

- Do not set `position` on an anchored `Control` to animate it. It freezes the size it has at that moment, even when
  its contents need less later. Animate `offset_left` and `offset_right` instead.
- Children are ready before their parents, so a signal emitted in a child's `_ready` reaches nobody yet.
  `QrCameraScanner` therefore starts deferred.
- On Linux, `CameraServer.camera_feed_added` arrives on another thread. Hand it to the main thread with `call_deferred`.
- A running tween keeps going after the view has changed. Stop it when leaving, or its last step will overwrite the
  new view (`_stop_reveal`).
- Flat buttons still reserve the margins of the theme's style. For an icon button use `TextureButton`.
- The catalog editor's `serializeCatalog` lists the fields it writes. A new card field has to be added there, or
  saving in the editor silently drops it.

**Assets**

- `art/` is not imported by Godot, so it is the place for sources and scripts. `art/import_onboarding_art.sh <folder>`
  brings in new artwork and `art/make_onboarding_sounds.py` makes the sounds.
- `ClassMagician.png` and `ClassWarrior.png` are still the same placeholder picture.
- Fonts need their licence shipped with them, which `include_filter` in `export_presets.cfg` takes care of.

**Battery**

The device lies on the table for a whole game with the camera on, so power matters. Rendering runs at 30 fps and
the camera slows down while nothing moves. See [Battery](qr_scanning.md#battery) before changing the camera or
adding continuous effects.
