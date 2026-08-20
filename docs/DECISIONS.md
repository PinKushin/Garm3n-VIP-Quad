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

**Now confirmed by observation, which is stronger than either argument.** With the
revert in place the owner built a full ÜberCharge on a local server and reported the
meter flashing — the `HudMedicCharged` loop cycling the meter white to transparent
every 0.6s. The animation layer works on the ORIGINAL order, which is the direct
evidence that the original order was never broken.

So the sequence was: I diagnosed a defect that did not exist, "fixed" it, thereby
creating the defect, and reverted on evidence from three other HUDs. The in-game
check closes it.

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

## 12. The 34 ScoreBoard.res gaps are design, not rot — confirmed by looking

The rot checker lists 34 substantive gaps in `ScoreBoard.res` (leader avatars,
`ClassModelPanel.CustomClassData` for all nine classes, `PlayerNameBG`, various `if_mvm`
variants). Nothing mechanical can tell whether Valve added those or Garm3n deleted them.

The owner settled it by using both scoreboards:

> "i belive the scoreboard is fine, the 6v6 and 18v18 or whatever it is, both work fine"

(6v6 / 16v16 here are this HUD's `cl_hud_minmode` toggle, bound to two menu buttons in
`GameMenu.res`, not separate scoreboards.)

So the omissions are Garm3n's redesign and should not be "fixed". This is exactly the
class of question the snapshot defers rather than answers, and the only instrument that
resolves it is a person looking at the running game.

Still unverified as of this entry: whether `MainBG` now covers the Damage/Support row
after entry 9 grew it. That is a separate question about a change I made, not about the
gaps above.

## 13. Adding a scoreboard stats row touches THREE coupled places

Adding the Damage/Support row took six attempts, four of them wrong, because the
stats block's layout is coupled across three panels that must all move together.
Written down so the next row costs one attempt instead of six.

**1. The box behind the stats is `LocalPlayerStatsPanel > HorizontalLine`.** An
`ImagePanel` at `zpos -3` with `fillcolor 0 0 0 150`. The name describes an old
purpose and is why three passes of reasoning never found it. Its `tall` is the span
from the first row down to the last, plus one row height — the original 65 was
exactly six rows (`r172`..`r122` = 50, plus 15). Seven rows needs 75.

**It is NOT `MainBG`.** `MainBG` backs the player list — above the stats in 16v16,
below them in 6v6, never behind them. I grew it twice and both times it overlapped
neighbours. There is now a comment on it saying so.

**2. The minmode cluster below must move down by the same amount.** Thirteen panels
(team bars, team scores, player counts, `MainBG`, both player lists). In 6v6 the
stats sit at the top, so a taller box eats into the team bar. `MainBG` also needs
its `tall_minmode` reduced by the same amount its `ypos_minmode` moved, or its
bottom edge runs into `ServerLabel`, which is not part of the cluster.

**3. The score block must re-centre.** `Kills2`, `Versus`, `Deaths2` and `MapName`.
Note these are in two different coordinate frames — the first three are children of
`LocalPlayerStatsPanel`, `MapName` is top-level — so their `r` offsets measure from
different origins and must be converted before comparing.

### The centring arithmetic was wrong, and predictably so

Computing it gave down 10 / 7; the answer that looks right is down 7 / 5. Centring
the block's bounding box on the panel's bounding box is not the same as looking
centred: `0:0` is a tall glyph with the map name beneath, so its optical centre sits
below its geometric one. No amount of arithmetic finds that.

### How the real panel was finally identified

By setting `MainBG`'s `fillcolor` to bright red and looking at both modes. That
should have been the first move, not the fifth. **When a panel cannot be identified
by reading, make it visible.** Coordinate reasoning here was repeatedly
self-consistent and wrong, and one screenshot settled it in seconds.

## 14. Corroboration finds DIFFERENCE, not defect — HudTournament.res proves it

The rot checker scores each gap by how many of rayshud, flawhud and budhud carry the
panel. `HudTournament.res` scored **30 of 30 at 3-of-3** — the only file to score
perfectly, and the strongest candidate the tool has ever produced.

The owner then loaded tournament mode with 11 bots and looked at it. It is fine. The
ready panel renders correctly, the per-player boxes fill the row edge to edge at 6v6
with no overlap, and it looks better full than empty.

**So a 3-of-3 score means "Garm3n differs from the other three", not "Garm3n is
broken".** The other HUDs carry those panels because they restyle them; Garm3n omits
them and inherits stock defaults, which look right. Both are valid outcomes and the
score cannot tell them apart.

That is still a large improvement over an unscored list — it took 275 absolute gaps
down to a handful of candidates — but the column is a **filter**, not a verdict. The
last step is always someone triggering the mode and looking.

Practical consequence for the remaining candidates (`HudObjectiveFlagPanel` 11,
`winpanel` 8, `HudMenuTauntSelection` 8): do not "fix" them from the gap list. Trigger
the mode, look, and change only what is visibly wrong.

Also worth keeping: 12v12 tournament mode WOULD overflow, since 24 boxes at 50 wide
is 1200 in a 640-wide space. It does not matter, because competitive is 6v6 and casual
12v12 uses HudMatchStatus rather than this panel.

## 15. Selectively suppressing the Options tooltips is NOT possible from the .res files

The Options and Advanced Options buttons show a mouseover tooltip that just repeats
the label already under the cursor. The icon row along the bottom also has tooltips,
and those ARE wanted. Three ways to suppress only the first pair were tried. All
three failed, each differently, and all three are recorded so they are not retried.

**1. Remove TooltipPanel entirely.** Kills every tooltip including the icon row's,
which is the opposite of what is wanted. `TooltipPanel` is a single shared panel;
there is no per-button instance to target.

**2. Park TooltipPanel offscreen (`ypos 9999`).** Did nothing at all.
`CHudMainMenuOverride` positions the tooltip at the cursor via `SetPos` when it shows
it, so the `.res` position is overwritten every time. A panel the client repositions
cannot be hidden by moving it.

**3. Declare the buttons in `GameMenu.res` with `"tooltip" ""`.** Tested on a branch
behind the smoke test, which passed — no crash. Then looked at, and it failed twice:
the buttons were **duplicated** on the menu, and the tooltips **still appeared**. The
client's hardcoded tooltip wins over an empty one in this file, and declaring a
control the client already builds produces a second copy.

**Why the difference exists at all:** in stock TF2 these two are ICONS with
`labelText ""`, so a tooltip naming them is doing real work. Garm3n gave them text
labels, which makes the client's tooltip redundant. The text comes from the client,
not from any file, and there is no tooltip key in `MainMenuOverride.res` for them —
the only `*tip*` keys stock defines there are `TooltipPanel`, `TipLabel`,
`TipSubLabel` and `RankTooltipPanel`.

**The one remaining route, not taken:** give those two buttons stock's empty
`labelText` and an icon, so the tooltip becomes the label instead of a duplicate of
it. That is a visual change to the menu rather than a fix, so it is the owner's call.

They were left visible with `TooltipPanel` at `zpos 10000` (stock's value; this HUD
shipped 1, which is why they drew UNDER the menu text and read as a glitch). Layered
correctly they are merely redundant rather than broken.

---

### C5. CORRECTION — "Garm3n" throughout this document means the HUD, not the author

I attribute design choices to Garm3n all over this file. That attribution is wrong,
and the repository history says so plainly:

```
33  pinkushin <pinkushin@verizon.net>     (this fork, 2026)
17  Hypnootize <9hypnotize3@gmail.com>    (everything before it)
```

**Every pre-fork commit is Hypnootize's, including "Initial commit" (2017-09-19).**
Jungle Inferno Update, Competitive Update Fix, Main Menu Fix, MvM Fix — all of them.
The owner supplied the context:

> "garm3n wasnt the last one to update this hud in 2017/2018 it was hypnotyze that
> updated all/or most of the old huds to the modern format so they wouldnt crash"

Garm3n designed the HUD — it carries his name, his fonts (`Garm3n42`, `Garm3nWhite`)
and his visual identity. But this repo contains none of his commits. It starts at
Hypnootize's import of an already-finished HUD, and everything after is his
compatibility work.

**Why this matters and is not pedantry.** The question this whole document keeps
circling — is a missing panel deliberate design or rot? — has a third answer I never
considered: it may be **Hypnootize stripping a panel in 2017-2018 to stop the HUD
crashing** on a then-current TF2. That is neither Garm3n's aesthetic nor Valve adding
surface, and it reads identically to both.

Entries 5, 8, 12, 13 and 14 all lean on "Garm3n deliberately chose this". Read those
as "the HUD as it stands does this, for reasons that may be Garm3n's design or
Hypnootize's compatibility work, and this repo cannot distinguish them." The
conclusions still hold — the squared corners and the stripped decoration are
consistent enough to be deliberate by someone — but the attribution does not.

There is no pre-2017 history here to check against, so distinguishing them would need
Garm3n's original release, which this fork does not contain.

### C6. CORRECTION — the "HudStopWatch is design" call was a measurement bug

I reported that `HudStopWatch.res` scored 0-of-3 against rayshud/flawhud/budhud —
every maintained HUD drops all 8 of its gaps — and concluded it was design rather
than rot, and told the owner not to bother with it.

That zero was a bug in my scorer, not a fact about the HUDs.

The scorer took the LAST dot segment of a gap path as the panel name. `HudStopWatch`'s
gaps all end in `.if_comp`, so it was searching every HUD for a control called
`if_comp`, which none contain. The score was structurally zero and could never have
been anything else. It silently affected every conditional gap in both corpora.

With the scorer stepping back to the panel the condition modifies, `HudStopWatch.res`
scores **8 of 8 in both** columns. Both corpora agree it is a genuine gap — the exact
opposite of what I reported.

**The lesson is the one this document keeps relearning:** a zero from an instrument is
not evidence until the instrument is shown able to produce a non-zero. I had a
"no maintained HUD carries this" result that was indistinguishable from
"my query matches nothing", and I reported the first reading without checking the
second. It surfaced only because the owner asked about Garm3n's other HUDs, which put
the same panels in front of me from a different direction.

### C7. Two corpora, and the same-author one is sharper

`refhuds/` is rayshud, flawhud and budhud — other authors, actively maintained.
`sibhuds/` is 18 of Garm3n's own HUDs from TF2HUDsArchive.

They answer different questions. "Do modern HUDs carry this?" conflates what TF2 needs
with what a designer chooses to style. "Does GARM3N carry this?" controls for taste,
because it is the same designer, so a difference is about THIS HUD.

Where they disagree, the same-author column is the one to trust. `winpanel.res` is the
clearest case: other authors style it (8 gaps carried), Garm3n never does (0 carried,
15 not). That is his choice, not rot — and the other-author column alone would have
sent us to "fix" it.
