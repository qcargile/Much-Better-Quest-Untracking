# Much Better Quest Untracking

A clean-room reimplementation of [Untrack Quest Ultimate](https://www.nexusmods.com/cyberpunk2077/mods/6328) (UQU) by anygoodname. Same feature set, ~33% less code, fewer compatibility issues, better defaults, a vehicle camera fix, and architecture you can actually maintain.

If you've been using UQU and ran into the **Merc Protocol incompatibility**, the **gamepad right-stick / look-behind conflict**, or just want a cleaner internal structure, this is for you. If you're new to quest untracking mods entirely, this is the one to install.

---

## Download

Grab the latest packaged release from the [Releases page](https://github.com/qcargile/Much-Better-Quest-Untracking/releases). Extract the archive and drop the `bin/` folder into your Cyberpunk 2077 install folder.

If you'd rather clone the source, the same `bin/` tree is mirrored under `bin/x64/plugins/cyber_engine_tweaks/mods/MuchBetterQuestUntracking/`.

---

## Why this over UQU

- **Compatible with Merc Protocol.** UQU's mod page documents this as a known incompatibility — UQU detects "last input device" via `PlayerLastUsedKBM`, which Merc Protocol shadows. MBQU does not detect input device at all (separate observe paths for KBM and pad), so the conflict cannot exist here.
- **Vehicle look-behind no longer fires alongside the gamepad untrack.** UQU's mod page lists this as unfixable — pressing the right stick to untrack also triggers vanilla's look-behind camera. MBQU's gamepad gesture is **context-aware**: on foot, long-press fires the untrack (quick tap is left to vanilla, e.g. crouch). In vehicle, quick tap fires the untrack (long-press is left to vanilla's look-behind). Same single button (default R3), no overlap with what vanilla wants the button to do in either context.
- **Fixer Reward objective list is editable.** UQU hardcodes the 6 objective hashes inside its `init.lua`. MBQU ships them in `data/fixer_reward_objectives.json` — when CDPR adds new gigs in a game patch, you can extend the list yourself without waiting for a mod update. An embedded fallback list ensures the guard still works if the JSON file is missing or invalid.
- **Hardened localization.** Auto-discovers community translations placed in `language/<locale>.json`. Logs a clear warning if `language/en-us.json` is missing or invalid (raw localization keys would otherwise leak into the settings menu).
- **Modular codebase.** UQU is one 2,612-line `init.lua`. MBQU is 13 files totaling ~1,580 lines, each owning one concern. MIT licensed, fully open source.

---

## Features

**Quest tracking control**
- Untrack the currently tracked quest objective from anywhere — gameplay, inventory, journal, world map, any menu.
- Track back (undo untrack) the last untracked objective. Falls back to the main quest if no recent untrack is remembered.
- Right-click directly on a tracked map marker to untrack it (KBM, default on).
- Gamepad track button on a tracked map marker to untrack it (default on).
- **Modifier-anywhere triggers** (rebindable):
  - KBM: hold modifier + right-click. Default modifier: Left Shift.
  - Gamepad: context-aware single button. Default: Right Stick click (R3). On foot — long-press to fire (quick tap left to vanilla). In vehicle — quick tap to fire (long-press left to vanilla's look-behind). Threshold configurable (default 500 ms).

---

## Requirements

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [Native Settings UI](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the in-game settings menu

## Install

Drop `bin/` into your Cyberpunk 2077 install folder. The mod appears as `MuchBetterQuestUntracking` in the CET overlay.

## Uninstall

Remove `bin/x64/plugins/cyber_engine_tweaks/mods/MuchBetterQuestUntracking/`.

---

## Compatibility

**Do not run alongside:** Untrack Quest Ultimate (disable UQU first).



## Known limitations

The on-screen GPS line doesn't always redraw when you track back. Two known cases:

- **Undiscovered objectives.** Vanilla's `TrackEntry` only accepts Active entries. Modifier+rclick retrack on an objective in an undiscovered area won't bring the GPS line back until you've actually found the location. Same limitation UQU has.
- **Off-road retracks.** The GPS path widget only draws when you're on a road. Tracking back while off-road may not trigger a redraw until you reach one (or until you click the mappin directly on the world map).

The journal-side state is correct in both cases; only the GPS line is conditional.

## Issue reporting

Before reporting, confirm: latest CET + game patch; the issue reproduces with only CET (and NUI, if used) + MBQU installed; the issue isn't already in "Known limitations" above. Then file with installed mods list, game version, CET version, and repro steps.

## Credits

- All of the creators of the mods this mod requires, and any creators from which this mod is derived.

## License

MIT — see [`LICENSE`](LICENSE).
