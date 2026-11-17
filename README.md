# Ashwright

A dark, minimal reskin of the WoW Forever default UI: flat bars, thin iron borders, crimson health, and a double iron frame on the pieces that appear once. Free, GPL-3.0-or-later, © 2026 Zudryx.

Ashwright only changes how Blizzard's frames look. It never moves secure frames, never replaces Blizzard functions and never changes what a button does. Anything that touches a Blizzard frame waits until you are out of combat.

## What it skins (0.1.14)

| Module | What changes |
|---|---|
| unitframes | Player, target, target of target, focus, party 1-4: frame art faded, flat bars on a dark panel, crimson health, power bars in the palette's rage, mana and energy colors, names in the title font with a shadow, lifted clear of the bars. The player, target and focus frames get the double iron border. Empty bars keep a dark trough. Power bars sit right under their health bars at the same width. The target's bars take the same size as yours, and when the target frame sits beside yours they line up with your bars. Target and focus buffs start below the panel instead of overlapping it. |
| actionbars | Bar art and end caps faded, square cropped icons on dark slots, one shared panel with the double border behind each group of touching bars, sized from the buttons showing, so bars join cleanly in any Edit Mode layout (hidden while Edit Mode is open); button dividers faded; bag buttons; flat XP and reputation bars in the accent color, with the rested-XP band kept as a dim stripe |
| minimap | Square, thin iron frame, round border and zoom buttons hidden, mouse-wheel zoom. Icons follow the square edge: other addons' minimap buttons and map pins are told the map is square (and refreshed if placed earlier), and Blizzard's tracking, mail, calendar, clock, queue and difficulty buttons move to the square's corners and edges. |
| castbars | Player, target and focus cast bars: art faded, flat fill on the same dark panel, colored by state (cast amber, channel green, can't interrupt grey, interrupted crimson), spell icon cropped square |
| chat | Chat font (each window keeps its size), a dark panel behind each chat window that also covers its scroll bar and input box, tab art faded, flat input box |
| nameplates | Flat health and cast bars with a thin border; your target's plate gets the accent border. Reaction colors are kept. |
| tooltip | Dark background, iron border, flat crimson health bar |

Portraits stay round for now, and raid frames are not skinned yet.

## Install

Copy the `Ashwright` folder into `World of Warcraft/<Forever client folder>/Interface/AddOns/`, so that the file `Ashwright.toc` sits directly in `AddOns/Ashwright/`.

## Commands

```
/ash                          status
/ash scan                     check which frames this client has (see below)
/ash module <name> on | off   turn a module on or off (then /reload)
/ash ornate on | off          double iron border on the player frame, bars and minimap
/ash chatpanel on | off       dark panel behind chat windows
/ash aligntarget on | off     line the target's bars up with yours
/ash nameoffset 4             how far names sit above the bars (pixels)
/ash inspect target | xp      record what is drawn on the target health bar or XP bar
/ash accent c9a75c            accent color
/ash errors                   anything that went wrong
/ash reset                    back to defaults
```

## First test: /ash scan

Forever's frame names can differ from other clients. Ashwright tries several known names for every frame and skips any it can't find. After logging in:

1. Type `/ash scan`. The chat shows how many frames each module found.
2. `/reload` so the game saves the results.
3. Send `WTF/Account/<ACCOUNT>/SavedVariables/Ashwright.lua`. It lists every frame name that was found and every one that was missing.

## Fonts

See `Ashwright/Media/README.txt` to use custom fonts. Without them, Ashwright uses the game's fonts.

## Tests

`test/harness.lua` runs the addon against a mock client in two layouts (classic-style and modern frame names), with and without combat at login:

```
texlua test/harness.lua Ashwright classic 0
texlua test/harness.lua Ashwright modern 1
```
