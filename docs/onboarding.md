# Onboarding

The first screen (`onboarding.tscn`, `scripts/onboarding.gd`). The device lies in the middle of the table, and up to
four players set up their heroes around it. Why it works this way is in [game_design.md](game_design.md).

## Flow

The screen shows the table. Players tap their place around the edge of the screen, which stands for their real place
at the table:

- **A free seat** opens the editor for a new hero.
- **A taken seat** opens the editor for the hero sitting there. So does tapping a hero in the middle of the screen.
- **A character or class card** shown to the camera opens the editor for a new hero with that card, who then shows
  their other card, gives a name and taps their seat. A card of a hero already at the table does nothing there (it
  may just be lying in view), and with 4 heroes no card does.

*Let's go!* (*Los geht's!*) appears once there is a hero, and leads to [choosing the boss](bosses.md), on the same
screen: the seats slide off the edges of the screen, the party sinks back and the boss list comes in. With 4 heroes,
free seats can no longer be tapped.

The name of the party is at the top of the screen. Tap it to type another one; the placeholder makes way while typing. It is optional, and long names get
smaller so that they stay readable between the seats.

## Editor

Everything about a hero is on one page, and can be done in any order:

- **Character card:** chooses the race and suggests a name that fits.
- **Class card:** chooses the class.
- **Name:** tap it to type another, or roll the dice for a new suggestion.

The buttons at the bottom, side by side and the same size:

- *Delete* (left) is there for a hero that already exists, and asks once more.
- *Done* (right) saves the hero and appears once there is a character, a class, a name and a seat.

Tapping the table outside the panel (but not on a seat) leaves without saving.

A hero started from a card has no seat yet: the free seats pulse, and the hint asks *Where are you sitting?* once
the cards and the name are there. To move a hero, tap a free seat while the editor is open. The seats show the move at once. *Done* saves it and
tapping the table puts the hero back.

The party is saved in `user://party.json` (`scripts/party.gd`) after every change. If a saved party exists, a returning
group only needs one tap. A hero that is still in the editor is not saved.

## Rules for cards

- Only character and class cards count, in the editor and at the table (see [Flow](#flow)). All other cards and
  unknown codes do nothing, without any message.
- Showing another card of the same kind replaces the choice.
- The card shown is kept with the hero (`race_card`, `class_card` in the party file), as it says their level: a level 5
  or 8 card gives the hero its ability in the fight (see [Cards](cards.md#hero-levels)). Showing a card of the same
  race or class at another level changes only the level.
- A card that was in view when the editor opened only counts after it has been out of view for 2 s. Otherwise a card
  a player is still holding would choose for the next hero, too.
- Each race and each class can only be picked once. A taken one is refused, the card frame shakes and the hint says
  who has it. A hero's own choices do not count as taken while changing them.

## Seats

Seats are numbered clockwise as seen on the screen: 0 to 2 down the right side, 3 at the table head at the bottom,
4 to 6 up the left side. Each seat is turned to face its player.

## Splash

The app starts on the logo (`assets/splash.png`, made by `art/build_icons.sh`). The engine's boot splash shows it while
loading, and the `Splash` node in the scene takes over with the same picture in the same place. It holds for about a
second, then fades while the table's intro plays. A tap skips the wait.

## Trying it out

On a laptop, press F5 in the editor or run `godot --path .`. The window is scaled down to fit a laptop screen.

- `art/dummy_cards.png` has a QR code for each of the dummy cards in `cards/cards.json` (`CHAR-…`, `CLASS-…`). Print
  it, or open it on a phone and hold that up.
- Debug builds show the camera picture, mirrored, in the frame while waiting for a card, because a laptop camera
  needs aiming. Laptop webcams have fixed focus: hold the code about 20 to 40 cm away, not closer.
- If the picture is the wrong camera (some laptops also list an infrared one), use the camera button at the top right.

## Replacing the placeholders

- **Real cards:** when the cards have been scanned, give them a `race` or `hero_class` ([cards](cards.md)) and delete
  the dummies. More than one card can stand for the same race or class.
- **Artwork:** `art/import_onboarding_art.sh <folder>` takes the finished images from a folder, with the same file
  names as now (`CharacterDwarf.png`, `ClassThief.png`, `Table.png`, …). The icons, buttons, controls and the dryad's
  form portraits come in through `art/import_ui_art.sh <folder>` (see [Artwork prompts](artwork_prompts.md)).
- **Music:** `music.tscn` is an autoload, so the track keeps playing from the onboarding into the game. It sets the
  track and its volume, which together with the default of the [music slider](settings.md) is kept low so that players
  can talk over it. New tracks need Loop on in their import settings.

## Credits

Fonts under the SIL Open Font License, next to the fonts in `assets/onboarding/fonts`: Almendra by Ana Sanfelippo,
Cinzel Decorative by Natanael Gama.
