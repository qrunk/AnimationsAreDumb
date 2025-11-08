# Animations Are Dumb
A mod for ***Balatro*** that speeds up all animations and transitons, so you can just play the game :)

# How to install

1) Install Steamodded (SMODS) for Balatro following its README. This typically creates a `Mods/` folder next to the game files and an in game Mods menu.
2) Copy the `NoAnimations` folder from this repository's releases into your Balatro `Mods/` directory.
3) Launch Balatro, open the Mods menu, enable "NoAnimations", then restart the game if prompted.

If you prefer, you can also symlink the folder for easy updates.

# Config Guide

Open `NoAnimations/config.lua` and adjust:

- `enabled` – turn the mod on/off without uninstalling
- `min_duration` – set to a tiny value like `0.01` if some sequences rely on a non-zero tween to complete
- Feature toggles under `features` – e.g., `skip_card_flips`, `instant_scoring`, etc.
- `background_duration` / `features.allow_background_transition` – let ambience/backdrops take a fraction of a second while everything else stays instant

The mod attempts three approaches, all guarded so they only apply if present in the runtime:

1. Clamp durations in common tween libraries (Timer/flux/tween.lua) to `min_duration` (with optional background overrides).
2. Nudge likely game settings (e.g., fast-forward/animation speed keys) to instant values.
3. Wrap common card methods and event manager timers to force animation delays down.

# Notes

- This is a best-effort, non-invasive mod. If your Balatro/SMODS version uses different function names, it may patch fewer things. It will still run safely.
- If something visually breaks or soft-locks, try `min_duration = 0.01` or `0.02` in `config.lua`.
- Compatible with most content mods; load order generally doesn't matter for this one, but if another mod replaces the same functions after load, its behavior may win.

# Licence
(C) Qrunk 2025 - Present, licenced under the Mozilla Public Licence.
