# Changelog

Each `## x.y.z` section becomes the release notes for that version.

## 0.1.19
- Nameplates: the level badge is replaced too. The game's gold-ringed badge and its selected ring are gone, and the number sits in a small Ashwright box. The skull for units far above your level stays.
- Nameplate cast bars are flat, on Ashwright's panel, in the same cast colors as your own. The interrupt shield and the "targeting you" mark stay.

## 0.1.18
- Nameplates: the game's rounded border and gloss are removed from the health bar, so only the flat bar on its thin dark frame is left. Heal prediction still shows.
- `/ash inspect plate` records what's drawn on your target's nameplate.

## 0.1.17
- The rested-XP stripe stays dim: the game was turning it fully solid.
- `/ash inspect target` looks for the target's buffs in more places and lists everything attached to the target frame.

## 0.1.16
- `/ash inspect target` records how the game keeps the target's buffs and finds them even when they aren't where it looked before, for fixing buffs that overlap the target frame.

## 0.1.15
First release. Ashwright gives the WoW Forever default UI a dark, minimal look: flat bars, thin iron borders, crimson health, and a double iron frame on the pieces that matter most. It only changes how the game's own frames look.

- **Unit frames** (you, target, target of target, focus, party): flat bars on a dark panel, crimson health, mana, rage and energy in the palette's colors, names in the title font lifted clear of the bars. Your frame, the target and the focus get the double iron frame. The target's bars take the same size as yours and line up with yours when the frames sit side by side. Buffs under the target and focus start below the panel.
- **Cast bars** (you, target, focus): flat, on the same panel, colored by what's happening: amber for a cast, green for a channel, grey when it can't be interrupted, crimson when interrupted.
- **Action bars:** square icons in thin slots; bars that touch share one panel.
- **XP bar:** flat, with a dim stripe for rested XP; the frame art, dividers and end caps are gone.
- **Minimap:** square, with the map buttons around its edge.
- **Chat:** a dark panel behind each chat window that also covers the scroll bar and the input box.
- **Nameplates and tooltips:** flat bars and dark backgrounds.
- Works in groups: nothing reads values the game keeps secret.
- `/ash` lists the commands. `/ash scan` and `/ash inspect target|xp` record what the game draws, for bug reports.
