# cfbseedR

Functions to efficiently simulate and evaluate college football seasons:
standings with a documented tiebreaker cascade, conference champions,
College Football Playoff (CFP) seeding, and week-by-week season simulation
with a pluggable results generator.

cfbseedR is **adapted from [nflseedR](https://nflseedr.com) (MIT)** by
Sebastian Carl and Lee Sharpe, part of the
[SportsDataverse](https://sportsdataverse.org).

## Installation

```r
# Not yet on CRAN. Install from GitHub:
remotes::install_github("sportsdataverse/cfbseedR")
```

## Quickstart

```r
library(cfbseedR)

# Bundled toy season (9 teams, 2 conferences + 1 independent)
games <- read.csv(system.file("extdata", "toy_games.csv", package = "cfbseedR"))
teams <- read.csv(system.file("extdata", "toy_teams.csv", package = "cfbseedR"))

# Standings with conference ranks and champions
standings <- cfb_standings(games, teams, tiebreaker_depth = "POINTS")

# Simulate a season 100 times (blank results are simulated)
games$result[games$week >= 3] <- NA
set.seed(42)
sim <- cfb_simulations(games, teams, simulations = 100, playoff_seeds = 4)
sim$overall

# Real data via cfbfastR (Suggests; the engine itself needs no cfbfastR)
# sched <- cfbfastR::load_cfb_schedules(2024)
# games <- cfb_games_from_schedule(sched)
```

## CFB semantics

* **Conferences, not divisions.** Standings group by conference;
  independents (`"FBS Independents"` or `NA` conference) appear in overall
  standings but get no conference rank.
* **Conference championship games** (`game_type == "CONF_CHAMP"`) count
  toward the overall record and decide the conference champion, but do
  **not** count toward the conference record/rank.
* **CFP 12-team straight seeding** (2025 rule) via `cfb_playoff_seeds()`:
  the 5 highest-ranked conference champions are guaranteed inclusion; the
  field is seeded strictly by committee rank (`rankings`).

## Documented simplifications vs. real CFB / nflseedR

* The tiebreaker cascade is **generic** (win pct → head-to-head → common
  opponents → SOV → SOS → point differential → coin flip), not the
  per-conference official tiebreak rules. All cascade quantities are
  computed over regular-season conference games so conference ranks depend
  only on conference play.
* `sov`/`sos` in the standings output are conference-scoped (opponents'
  conference records over conference games); independents get 0.
* When `rankings = NULL`, `cfb_playoff_seeds()` falls back to ordering
  teams by win pct, SOV, SOS, and point differential instead of a
  committee ranking.
* Committee `rankings` are static across simulations.
* Conference championship matchups are simulated **as scheduled** — the
  engine does not re-derive participants from simulated standings.
* Playoff games are generated only when the input `games` has no
  `game_type == "POST"` rows; the first round is hosted by the higher
  seed, later rounds are neutral-site.
* No draft order (not a CFB concept).
* No chunked/parallel simulation (nflseedR's `chunks`/future support);
  simulations run sequentially.

## Attribution

The architecture (standings init → conference ranks → seeds; week-loop
simulation with pluggable `compute_results`; ELO-based default results
generator) is a direct adaptation of
[nflseedR](https://github.com/nflverse/nflseedR) (MIT), Copyright (c)
Lee Sharpe and Sebastian Carl.
