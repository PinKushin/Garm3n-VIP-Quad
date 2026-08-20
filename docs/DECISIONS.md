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

### C2. REVERSAL — animation load order: TF2 keeps the FIRST definition, not the last

**Position I took:** the manifest listed `hudanimations_custom.txt` before
`hudanimations_tf.txt`, therefore all 15 of this HUD's animation events were being
overwritten by stock and the whole animation layer was dead. I moved custom last
and called it verified.

**Position after evidence:** the original order was correct. TF2 keeps the first
definition. My change is what silenced the animations.

**What changed my mind:** three actively maintained HUDs, all of which load custom
*before* `hudanimations_tf.txt`:

| HUD | Version | Custom events | Also defined in stock tf.txt |
|---|---|---|---|
| rayshud | 2026.0111 | 24 | 20 |
| flawhud | 2026.0110 | 23 | 19 |
| budhud | 2511_01 | across 11 files | many |

The overlapping names are the same ones this HUD defines — `HudHealthBonusPulse`,
`HudHealthDyingPulse`, `HudLowAmmoPulse`, `HudMedicCharged`. All three HUDs
demonstrably have working pulses. Under last-wins, all three would be broken too.

**Why I got it wrong, which is the part worth keeping:** I inferred the semantics
from a single artifact — Valve commented out a `TextColor` line in tf.txt's copy of
`OpenWeaponSelectionMenu`, and I argued that edit is a no-op unless the later file
replaces the earlier. Under first-wins the HL2 file wins those seven shared events
and tf.txt's copy is simply dead code, which explains a stale commented line just as
well. I had one ambiguous artifact and called it verification. Differential evidence
across independent implementations beat it outright.

### C3. REVERSAL — omitting a stock menu panel is safe; declaring it badly is not

**Position I took:** a panel the client constructs but the `.res` never names keeps
its constructor geometry, usually the top-left corner, so every unwanted stock panel
must be explicitly declared and zeroed.

**Position after evidence:** wrong, and it crashed the game. Pristine `master` omits
all twelve panels and launches fine, so omission is demonstrably safe.

**What changed my mind:** bisection. `master` launches; `6d1f423` (gitattributes +
manifest + clientscheme + scoreboard) launches; adding the menu commit crashes at the
main menu. Best suspect is `VRModeButton`, which stock declares as an `EditablePanel`
carrying a `SubButton` child plus `navToRelay "SubButton"` — I declared it with no
child, so a navigation lookup for that relay finds nothing.

The general lesson: adding a declaration for a control the engine already builds is
not a free safety measure. A partial declaration is more dangerous than no
declaration, because the engine trusts what the `.res` says the control contains.

### C4. REVERSAL (by the owner) — test harness language

The owner first chose PowerShell + Pester, then reversed on learning the suite would
live in its own repository:

> "actually if its going to be a separate project, that becomes kinda its own thing,
> it would probably be better to use C#, over powershell and pester, i picked
> powershell because i was thinking it would be in the huds own repo. I worry that is
> a larger project than i need though."

Recorded because the reasoning is conditional, not absolute: Pester was the right call
*for an in-repo script*, C# is the right call *for a standalone tool*. The stated
worry about scope is part of the decision and is why the suite is being staged rather
than built all at once.

---

## 9. Scoreboard background grown by one row

`MainBG` was one stats row too short once Damage/Support were added, so the last row
rendered past the bottom of the panel. Confirmed by looking at the running game —
the placement was explicitly flagged as unverifiable when the row was added, and
neither a coordinate assertion nor the author's 2017 screenshot could settle it.

Grown by exactly one row on each ladder rather than a round number: `tall` 250 → 260,
`tall_minmode` 106 → 113 (the ladders step 10 and 7), MvM variant 171 → 181.

## 10. Rot detection reports a DELTA, not absolute gaps

Run absolutely, the checker finds 275 gaps against the shipped stock HUD, and nearly
all are Garm3n deliberately stripping stock decoration in 2017 — every
`titlelabeldropshadow`, `divider`, `mainbackground` and `numberbg`. From a single
snapshot "Valve added this" and "the author removed this" are indistinguishable: both
are a block in stock that is not here.

Change over time is distinguishable. So `tests/rot-snapshot.txt` records the known gap
set and a run reports only what is new since. A tool that cries 275 times is a tool
nobody reads.

The snapshot must never be regenerated without reviewing the delta first, or new rot is
laundered into the accepted set and the tool becomes decorative.

## 11. The four dangling fonts use Garm3n's Default, on the owner's instruction

`HudMenuNumberFont`, `Garm3n`, `Garm3nFontTargetSmaller` and `HudFontGarm3nTiny2` are
referenced by this HUD's `.res` files and were never defined anywhere — not here, not in
stock. They are not new rot; they have been dangling since the HUD was written, and every
panel using one has been rendering in the *engine's* fallback face rather than Garm3n's.

The owner's direction:

> "if its default font it should probably use whatever garmen uses as his default"

So all four are defined identically to this scheme's `Default` — Novecentowide-DemiBold
at 10.

**Sizes were deliberately not invented.** Two names hint at one (`HudFontGarm3nTiny2`
wants smaller, `Garm3nFontTargetSmaller` likewise) and `HudMenuNumberFont` draws
build-menu slot numbers which probably wants larger, but a guessed number is a confident
wrong answer that nobody later knows to question. They match `Default` until someone
looks at them.
