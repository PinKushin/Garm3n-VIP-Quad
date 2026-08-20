# Decisions

Numbered, newest at the bottom. Each entry records what was decided and *why*,
because the code shows only the outcome and a decision made for a good reason is
indistinguishable from an arbitrary one once the conversation is gone.

Where the reason was not stated, that is recorded as an honest gap rather than
filled in with a plausible-sounding rationale.

---

## 1. Fork target: modernize against live TF2, not against upstream

Upstream is `TF2HUDsArchive/Garm3n-VIP-Quad`, last pushed 2024-04-16, and its
last actual content commit is 2023-01-06 ("MvM Fix"). The main menu was last
touched 2018-04-09. This fork is even with upstream, so there is nothing to pull;
"what needs updating" means diffing the HUD against the shipped game, not against
the parent repo.

Method used throughout: extract `resource/` and `scripts/` from the installed
`tf2_misc_dir.vpk` (plus `scripts/hudanimations.txt` from `hl2_misc_dir.vpk`) and
diff the HUD's files against those. The game is the moving target; the archive is
not.

## 2. `.gitattributes` set to `* text=auto eol=lf`

Applied from the owner's global engineering standards, which require LF in the
repository *and* in the working tree.

The repo already stored LF, because bare `text=auto` normalizes on commit, but
`text=auto` checks out CRLF on Windows, so the working tree disagreed with what
was committed and every LF-writing tool produced a conversion warning.

Checked before converting: `git ls-files | grep -iE '\.(bat|cmd)$'` returns
nothing, so no file here requires CRLF to execute. Fonts pinned `binary`.

Tradeoff accepted: this diverges the whole tree from upstream's line endings,
which would matter if upstream were alive. It is not.

## 3. Fix order set by the repository owner

The owner chose: animation manifest, then ClientScheme fonts, then scoreboard,
then main menu. This matched the recommendation given (cheapest-and-highest-impact
first), and the owner did not state a separate reason of their own.

## 4. `hudanimations_custom.txt` moved last in the manifest

See commit "Load hudanimations_custom.txt last so its events actually take
effect". The load-order claim was verified against shipped data rather than
assumed: `hudanimations_tf.txt` redefines 7 events from `hudanimations.txt`, and
in its copy of `OpenWeaponSelectionMenu` Valve commented out a line the base file
sets. That edit is a no-op unless the later file replaces the whole event.

## 5. Three stock fonts deliberately NOT restored

`ScoreboardTeamNameNew`, `ScoreboardTeamCountNew`, `ScoreboardTeamScoreNew` are
referenced only by the stock `scoreboard.res`, which this HUD fully overrides with
its own fonts. Defining them would add entries nothing can ever ask for.

The other seven gaps were real and were closed. `CloseCaption` was deliberately
left as stock Tahoma rather than restyled, because captions are an accessibility
feature and a decorative face with a narrow glyph range makes them harder to read.

## 6. `CustomFontFiles` gaps left alone

The HUD's `CustomFontFiles` omits stock entry 7 (`resource/ocra.ttf`) and entries
10-17 (`resource/linux_fonts/*`).

Dropping `ocra` is harmless: no font in this scheme is named `ocra`, so nothing
asks for it. The `linux_fonts` entries are the DejaVu/Liberation/FiraSans
fallbacks that native Linux clients use for non-Latin text, and their absence is
plausibly a real regression — but it cannot be observed from a Windows install,
so it was left alone rather than guessed at.

## 7. Missing menu panels zeroed, not omitted

A panel the client constructs but the `.res` never mentions keeps whatever
geometry its constructor gave it, typically the top-left corner. Omission is
therefore not equivalent to hiding.

Panels this HUD replaces with its own equivalents (`WorkshopButton`,
`ReplayButton`, `SettingsButtonSDK`, `TF2SettingsButtonSDK`) and removed features
(`VRBGPanel`, `VRModeButton`) are defined with zero size and `visible 0`. Panels
that convey information (`NoGCMessage`/`NoGCImage`, `SafeMode`,
`CompetitiveAccessInfoPanel`, `StoreHasNewItemsImage`) are carried over from stock
unchanged, because each is hidden until the client shows it and a panel that
cannot be triggered on demand cannot be restyled against anything observable.

`ReportPlayerButton` is the one that was genuinely wanted, and it needed an entry
in **both** `MainMenuOverride.res` (position) and `GameMenu.res` (creation).

## 8. Seasonal menu backgrounds not added

Stock `MainMenuOverride.res` defines `background.if_halloween_*` and
`background.if_christmas_*` variants; this HUD defines none, so the menu art does
not change for events. That reads as a deliberate choice by the original author
rather than rot, so it was left alone. Revisit if the owner wants event art.

---

## Corrections recorded

### C1. The README screenshot links are NOT broken

Initially reported as six dead links because `screenshots/` does not exist in the
working tree. The repository owner corrected this:

> "the fatehr repo has the screenshop branch, i just didnt fork the whole thing btw"

That is the Hypnootize HUD-repo convention: from a blob URL, `../screenshots/x.md`
resolves to the `screenshots` **branch**, not to a sibling directory. Verified:
upstream has `refs/heads/screenshots` containing `showcase.md` and all five `.jpg`
files, and all six README links resolve against it.

The fork has only `master`, so the branch was fetched locally as `screenshots`.
It still needs pushing to `origin` for the links to work on the fork's own README.

Lesson worth keeping: a relative link in a GitHub README is not a filesystem path,
and "the file is not in this checkout" is not evidence that a link is dead.
