# Onboarding

The first screen (`onboarding.tscn`, `scripts/onboarding.gd`). The device lies in the middle of the table, and up to
four players set up their heroes around it. Why it works this way is in [game_design.md](game_design.md).

## Flow

Each hero goes through three steps:

1. **Character:** show a character card. This chooses the race and suggests a name that fits. Tap the name to type
   another, or roll the dice for a new suggestion.
2. **Class:** show a class card.
3. **Seat:** tap one of the 7 places around the edge of the screen, which stand for the real places at the table.

Then the party screen shows all heroes. From there, players add a hero, tap a hero to change or remove them, or
start the game with *To Battle!*, which loads `main.tscn`.

## Changing your mind

- **During setup:** the steps at the top show what was chosen. Tap one to go back to it, or forward to a step that
  is already possible. Nothing is lost by moving around. The name can be edited in every step.
- **Later:** tap the hero on the party screen or at their seat, change what you like and press *Done*. *Back* on
  the first step leaves without saving the change.

The party is saved in `user://party.json` (`scripts/party.gd`) after every change. If a saved party exists, the
game opens on the party screen, so a returning group only needs one tap. A hero that is still being set up is not
saved.

## Rules for cards

- A card only counts in the step it matches: all other cards and unknown codes do nothing, without any message.
- Showing another matching card replaces the choice.
- A card that was in view when the step began only counts after it has been out of view for 2 s. Otherwise a card
  a player is still holding would choose for the next hero, too.
- Each race and each class can only be picked once. A taken one is refused, the hint says who has it, and its tile
  shows that hero's name. A hero's own choices do not count as taken while changing them.

## Seats

Seats are numbered clockwise as seen on the screen: 0 to 2 down the right side, 3 at the table head at the bottom,
4 to 6 up the left side. Each seat is turned to face its player.

## Trying it out

On a laptop, press F5 in the editor or run `godot --path .`. The window is scaled down to fit a laptop screen.

- `art/dummy_cards.png` has a QR code for each of the dummy cards in `cards/cards.json` (`CHAR-…`, `CLASS-…`). Print
  it, or open it on a phone and hold that up.
- Debug builds show the camera picture, mirrored, in the frame while waiting for a card, because a laptop camera
  needs aiming. Laptop webcams have fixed focus: hold the code about 20 to 40 cm away, not closer.
- If the picture is the wrong camera (some laptops also list an infrared one), use the camera button at the top right.
- In debug builds, the small pictures of the options can also be clicked. This is for testing without a camera or
  cards, and release builds do not have it.

## Replacing the placeholders

- **Real cards:** when the cards have been scanned, give them a `race` or `hero_class` ([cards](cards.md)) and delete
  the dummies. More than one card can stand for the same race or class.
- **Artwork:** `art/import_onboarding_art.sh <folder>` takes the finished images from a folder, with the same file
  names as now (`CharacterDwarf.png`, `ClassThief.png`, `Table.png`, …).
- **Sounds:** `art/make_onboarding_sounds.py` creates them.

## Credits

Fonts under the SIL Open Font License, next to the fonts in `assets/onboarding/fonts`: Almendra by Ana Sanfelippo,
Cinzel Decorative by Natanael Gama.
