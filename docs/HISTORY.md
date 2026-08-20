# Provenance

Who this HUD was for, who made it, and who kept it alive. Recorded because the name
on the repository is a person, and none of this is in the code.

---

## quad — the player it was built for

**Christian "quad" Sørensen**, Danish, Scout. A pro-level player in European competitive TF2 from
roughly 2011 to 2015, with a final appearance in 2019.

Known for DM and tracking, **particularly with the pistol**. The nickname is the quad
damage pickup from Quake — which is the whole thread running through Garm3n's work
(see below).

### Peak: 2011, two LAN wins back to back

| Date | Event | Team | Result |
|---|---|---|---|
| 2011-08-28 | **Insomnia43** | Epsilon | **1st**, beat Infused 2:1 |
| 2011-11-20 | **Insomnia44** | Infused | **1st**, beat Aegyo 2:0 |
| 2011-04-24 | Insomnia42 | Poop | 3rd |
| 2011-08-05 | Assembly Summer 2011 | qn. | 5th–6th |

Winning i43 with Epsilon and then i44 with Infused means he took consecutive major
LANs with the two dominant European rosters of that era — and beat the other one each
time.

### ETF2L Premiership, 2012–2013

Five consecutive Premiership seasons, which is the top European division:

| Season | Team | Place |
|---|---|---|
| S11 | k-es. | 6th |
| S12 | Decerto | 7th |
| S13 | (-.-) | 8th (won the qualifier 2:0 over uV) |
| S14 | BFF | 4th |
| S15 | RLM | 4th |

Also Highlander Premiership — **2nd** in S3 with G4P3, **3rd** in S4 — and 3rd–4th at
ETF2L Nations Cup #3 representing **Denmark**.

Later: 1st in the ETF2L Season 21 preseason Premiership playoffs (2015, team "lol"),
and 13th–16th at Copenhagen Games 2019 Open Groups with pheas.

---

## Garm3n — the HUD maker

Garm3n built HUDs for competitive players. The archive at `TF2HUDsArchive` holds
**19** of his HUDs, and the naming makes the practice explicit:

```
Garm3n-VIP-Quad      Garm3n-VIP-Beavern    Garm3n-VIP-Konr
Garm3n-VIP-Stefan    Garm3n-VIP-SL         Garm3n-VIP-Garm3n
```

`VIP-<handle>`, one per player. **konr** and **BeaVerN** both check out as real ETF2L
competitors, so these are commissions rather than themed releases.

**The Quake thread.** The rest of the lineup is `Garm3n-QL` (Quake Live), `Garm3n-Q-M`,
`Garm3n-OLX`, `Garm3n-REX`, `Garm3n-8MG`, `Garm3n-4MP`, `Garm3n-7MF`. tf2huds.dev
describes them as Quake-style layouts. Quake players arriving in TF2 and wanting the
HUD they were used to — and quad's own handle comes from a Quake pickup.

Whether Garm3n competed himself is **not established**. Nothing found either way;
recorded as unknown rather than denied.

---

## Hypnootize — who kept it working

Every pre-fork commit in this repository is Hypnootize's, including the initial one:

```
17  Hypnootize <9hypnotize3@gmail.com>    2017-09-19 .. 2024-04-08
```

Garm3n designed the HUD; Hypnootize imported it already finished and maintained it
through Jungle Inferno, the Competitive update, the 2018 main menu changes and an MvM
fix. He did this across most of the old HUD archive, keeping them loading on a TF2
that had moved on without them.

There is no pre-2017 history here, so this repo cannot distinguish Garm3n's original
design decisions from Hypnootize's compatibility work. That matters when reading
`DECISIONS.md` — see correction C5.

---

## Sources

- [quad — Liquipedia](https://liquipedia.net/teamfortress/Quad) and
  [results](https://liquipedia.net/teamfortress/Quad/Results) (results supplied by the
  repo owner; Liquipedia returns 403 to automated fetches)
- [quad — comp.tf](https://comp.tf/wiki/Quad)
- [quad — ETF2L profile](https://etf2l.org/forum/user/14836/)
- [konr — ETF2L profile](https://etf2l.org/forum/user/20891/)
- [Garm3n QL — tf2huds.dev](https://tf2huds.dev/hud/Garm3n-QL)
- `git shortlog` of this repository, for the Hypnootize attribution
