extends Node
## The fight the party has chosen: which boss, and how hard. As an autoload it carries the
## choice from the boss screens into the fight, and keeps it while the app runs, so that
## coming back to the boss screens shows the last choice again.

## An id from Bosses.BOSSES, or empty while none is chosen.
var boss := ""
## An id from Bosses.DIFFICULTIES.
var difficulty := Bosses.DEFAULT_DIFFICULTY
