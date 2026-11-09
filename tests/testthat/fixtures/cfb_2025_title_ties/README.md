# `cfb_2025_title_ties` — real 2025 ACC and SEC conference games

These are the real 2025 regular-season conference games for the ACC (69) and
the SEC (64), with final scores. Both leagues finished with a multi-team tie
for a title-game berth that the order-of-finish descent rung has to handle:

- **ACC:** Virginia finished first at 7-1. Duke, Georgia Tech, Miami, Pitt and
  SMU tied at 6-2. No conference opponent was played by all five, so steps A-D
  could not separate them. Opponents' combined conference win % put Duke in,
  and the title game was Virginia vs Duke.
- **SEC:** Alabama, Georgia, Ole Miss and Texas A&M tied at 7-1. The title game
  was Alabama (seed 1, the designated home team) vs Georgia (seed 2).

Both engines must give these pairs in this order: sdv-py's
`tests/cfb/test_cfb_standings.py::TestCommonOpponentDescent` and this
package's `tests/testthat/test-tiebreakers.R`. Background: sportsdataverse/cfbseedR#14 and
sportsdataverse/sportsdataverse-py#1140. The CSVs are byte-identical to sdv-py's `tests/fixtures/seedr/cfb_2025_title_ties/`.

## Provenance

- **Source:** `sportsdataverse.cfb.load_cfb_schedule([2025])`, the
  sportsdataverse-data `cfb_schedules` release.
- **Build:** run through cfbseedR's `cfb_games_from_schedule()`, keep
  completed `REG` games where both teams are in the same conference (ACC or
  SEC), and keep `home_points`/`away_points` for the SEC's capped scoring
  margin rung.
- **Files:** `games.csv` holds the game rows (with `season`, so the 2024-2025
  ACC policy epoch applies). `teams.csv` holds the 33 teams and their
  conferences.
