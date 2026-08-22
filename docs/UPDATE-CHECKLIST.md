# Update checklist

Hypnootize maintained most of the old HUD archive and wrote down the process:
**[HUDs-Update-Guide](https://github.com/Hypnootize/HUDs-Update-Guide#readme)**. It is a
curated list of what breaks in an old HUD, per TF2 update, by the person who did it
across a hundred of them.

This file maps that guide onto **this** HUD. Check it after a TF2 update, alongside
`tests/Invoke-HudRotCheck.ps1`.

---

## His guide explains this repo's history

The commit log maps onto his own checklist almost line for line, which is good evidence
the HUD was maintained deliberately rather than patched ad hoc:

| Commit here | Guide item |
|---|---|
| 2017-10-21 `Jungle Inferno Update` | new weapon meters, war paints, New Item Found panel |
| 2018-03-29 `Competitive Update Fix` | MatchStatus / tournament panel |
| 2018-04-09 `Main Menu Fix` | Fix the Main Menu |
| 2020-08-24 `Chat Fix.` | Fix chat positioning (Summer 2020) |
| 2023-01-06 `MvM Fix` | Fix misplaced MvM Money (Smissmas 2022) |

---

## Status against the guide

### Mandatory

| Item | State |
|---|---|
| Add `info.vdf` | **Done.** Present, `ui_version 3`. |
| Update animations | Done, and note the manifest order is CORRECT as shipped — TF2 keeps the FIRST definition. See DECISIONS C2, where changing it broke every animation. |
| Update HudLayout | **Complete** — the rot checker reports zero missing elements. |
| Update ClientScheme | **Done.** Six stock fonts restored 2026-08. `CustomFontFiles` still omits `ocra` and the Linux fallbacks, and neither is a gap — see DECISIONS 17: this HUD ships its own faces, so nothing it draws with needs a system substitute. |
| Remove outdated files | Appears done by Hypnootize; no crash-on-load. |

### Main

| Item | Applies here? |
|---|---|
| Fix Main Menu | Done 2018. Tooltips fixed 2026 (`zpos 1` → `10000`). |
| Fix MatchStatus and Timer | Overridden here; done 2018. |
| Fix Scoreboard | Overridden; verified in both modes 2026. |
| Fix Tournament Panel | Overridden; **verified fine by looking** — see DECISIONS 16. |
| Fix WinPanel | Overridden. **Verified by the owner, 2026-08-21** — it is fine. |
| Fix Vaccinator UI | Not overridden — stock fallback. |
| Add new weapon meters | Present, plus `HudItemEffectMeter_Action.res` added 2026 (it was missing and spamming the console). |
| Fix chat positioning | Done 2020. |
| Add killstreak counter | Present. |
| Add 3D player model | **Verified by the owner, 2026-08-21** — it is fine. |
| Add missing status icons | **Verified by the owner, 2026-08-21** — they are fine. |
| War paints support | Presumed done with Jungle Inferno. |
| Fix New Item Found panel | Presumed done with Jungle Inferno. |
| Fix misplaced MvM money | Done 2023. |
| **Fix invisible loadouts (64BIT 2024)** | **Does not apply.** The fix is `settitlebarvisible` `0` → `1` in `Resource/UI/CharInfoPanel.res`, and this HUD does not override that file, so it inherits the corrected stock version. This is the only guide item postdating the last maintenance commit, and it is a non-issue by luck of omission. |

### Optional

`CharInfoPanel`/`StorePanel` tabs, spectator item panels, floating health cut-off, class
selection model transparency — none verified, all cosmetic.

---

## The general point

Not overriding a file is a **defence**. Every guide item that lands on a file this HUD
leaves alone is automatically fixed, because the fallback is stock and stock is current.
The 64BIT loadout bug is exactly that: the most recent breaking change in the guide, and
it cannot touch us.

That is the same mechanism the rot checker exists to police from the other direction —
overriding a file freezes it, and everything Valve adds to it afterwards is silently
lost.
