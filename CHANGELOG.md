# Changelog

Each `## x.y.z` section becomes the release notes for that version.

## 0.1.26
- Target and focus buffs: Ashwright now moves the frame that holds them (inside the unit frame's content), not only the ones it found before. The buffs should sit just below the panel's outer edge.
- `/ash dump` also walks the player, target and focus frames' own children. It records any the game leaves out of its frame list, marked `C`.

## 0.1.25
- `/ash dump` also lists the auras the game says your target has. It now keeps hidden frames too when they belong to the target or are laid out like an aura button (marked `H`). Together these show whether the target's buffs exist as frames at all, and where.

## 0.1.24
- `/ash dump` now keeps frames the game won't say are shown or hidden (it answers with a secret). These were dropped before, which left the target's buffs out of the dump. They're marked `F?`, and the count is shown when the dump finishes.

## 0.1.23
- `/ash dump` records everything on screen at once: every visible frame (not just the ones Ashwright knows), with its parent, position, what it hangs from, and its art and text. One dump answers what any piece of the screen is, so fixes come from data. `/ash dump clear` removes it from your saved settings.

## 0.1.22
- `/ash inspect target` also records every frame drawn just under the target frame, found by where it sits on screen.

## 0.1.21
- Target and focus buffs no longer overlap the frame. WoW Forever keeps them in a container outside the frame, hung under it; Ashwright now finds that container and moves it below the panel.
- `/ash inspect target` lists that container.

## 0.1.20
- `/ash inspect target` searches the whole target frame, and every frame the game names for target buffs, wherever it's attached.

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
