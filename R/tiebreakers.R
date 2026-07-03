# Official per-conference tiebreaker registry + rung-dispatch engine.
#
# Ported from sdv-py's `sportsdataverse/cfb/cfb_standings.py`
# (`CONFERENCE_TIEBREAKERS`, `_GENERIC_CASCADE`, `_apply_h2h` /
# `_apply_record_vs_common` / `_apply_record_vs_common_desc` / `_apply_rung`,
# `_pick_winner` / `_order_tied` / `_add_conf_ranks`) so both engines produce
# byte-identical standings on the shared cross-language parity fixture
# (`tests/testthat/fixtures/cfb_toy_tiebreakers/`).
#
# A "rung" is a named list `list(kind = ..., <params>)`. A conference's
# tiebreaker procedure is a plain list of rungs; `.pick_winner()` /
# `.order_tied()` are the ONE dispatch path for both the official registry
# procedures below and the pre-existing generic fallback (`.generic_cascade`,
# still gated by `tiebreaker_depth` via each rung's `min_depth`; registry
# rungs have no `min_depth` and always run in full).
#
# Adopted ambiguity resolutions (mirroring the Python module docstring):
# * "combined win percentage of conference opponents" for the registry's
#   `opp_conf_win_pct` rung is POOLED (sum of opponents' conference wins /
#   sum of their conference games). R's pre-existing `sos` column already
#   computes exactly this (sum(opp_wins)/sum(opp_games) over conference
#   games played) - unlike Python, which stores a per-game MEAN in `sos`
#   and needed a separate pooled column, R's `opp_conf_win_pct` rung simply
#   reuses the existing `sos` metric (see `standings_add_conf_ranks()`).
# * The Big 12 grouped-ties descent rule (compare a tied set's record vs a
#   tied GROUP of common opponents collectively) applies to every registry
#   descent rung (`record_vs_common_desc`), regardless of its `mode` label
#   (`"order_of_finish"` vs `"next_highest"` - both dispatch through the
#   same `.apply_record_vs_common_desc()`; the label is documentation only,
#   mirroring the Python implementation exactly).
# * Multi-team combined head-to-head applies only when every tied pair
#   played each other; otherwise only "defeated-all" elimination applies
#   (seeding the team that beat every other tied team it played).
#   ponytail: the symmetric "lost-to-all" elimination is NOT separately
#   modeled - a team stuck at the bottom of a tied group surfaces via
#   `record_vs_common` / `opp_conf_win_pct` in practice. Upgrade path: add
#   an explicit "confirmed-last" branch in `.apply_h2h()` if a real fixture
#   ever needs it.
# * After each team is seeded/eliminated, the tie restarts from rung 1 with
#   the remaining set (`.order_tied()`); reducing to two candidates simply
#   re-enters the same rung list (all registry conferences use ONE rung
#   list for both the 2-team and 3+-team cases, matching the official SEC
#   text and the Python port).
# * Rungs whose optional input is absent (per-game points, an FBS/FCS
#   `division` flag on `teams`, analytics ratings) are skipped
#   deterministically; each skip is recorded once in the `tiebreak_notes`
#   attribute of `cfb_standings()`'s result (see `.note_add()`).

SEC_OFF_CAP <- 42
SEC_DEF_CAP <- 48
B12_FCS_CAP <- 1L

# Pre-existing generic cascade, expressed as a rung list so it shares the
# ONE dispatch path with the registry procedures below. `min_depth` is the
# `tiebreaker_depth` gate (byte-identical behavior to the pre-registry
# `break_tie()`); registry rungs have no `min_depth` and always run.
.generic_cascade <- list(
  list(kind = "h2h", min_depth = 1L, generic = TRUE),
  list(kind = "record_vs_common", min_depth = 1L),
  list(kind = "sov", min_depth = 2L),
  list(kind = "sos", min_depth = 2L),
  list(kind = "conf_pd", min_depth = 3L),
  list(kind = "coin_toss", min_depth = 0L)
)

# Big Ten / ACC / MAC share one official template: head-to-head, common
# opponents, order-of-finish descent, pooled opponents' conference win pct,
# an external analytics rating, then a draw.
.p5_template <- list(
  list(kind = "h2h"),
  list(kind = "record_vs_common"),
  list(kind = "record_vs_common_desc", mode = "order_of_finish", grouped_ties = TRUE),
  list(kind = "opp_conf_win_pct"),
  list(kind = "analytics_rating"),
  list(kind = "coin_toss")
)

#' Official 2024+ conference tiebreaker procedures (internal registry)
#'
#' A named list of rung lists, one per registered conference. Conferences
#' not listed here use `.generic_cascade`. G5 conferences intentionally stay
#' on the fallback - their published procedures depend on unspecified
#' external metric composites (see the design brief).
#' @noRd
CONFERENCE_TIEBREAKERS <- list(
  "SEC" = list(
    list(kind = "h2h"),
    list(kind = "record_vs_common"),
    list(kind = "record_vs_common_desc", mode = "order_of_finish", grouped_ties = TRUE),
    list(kind = "opp_conf_win_pct"),
    list(kind = "capped_scoring_margin", off_cap = SEC_OFF_CAP, def_cap = SEC_DEF_CAP),
    list(kind = "coin_toss")
  ),
  "Big Ten" = .p5_template,
  "ACC" = .p5_template,
  "MAC" = .p5_template,
  "Mid-American" = .p5_template, # cfbfastR schedule naming for the MAC
  "Big 12" = list(
    list(kind = "h2h"),
    list(kind = "record_vs_common"),
    list(kind = "record_vs_common_desc", mode = "next_highest", grouped_ties = TRUE),
    list(kind = "opp_conf_win_pct"),
    list(kind = "total_wins", fcs_cap = B12_FCS_CAP),
    list(kind = "analytics_rating"),
    list(kind = "coin_toss")
  )
)

# Record (pts, n) of `team` versus `opps` within one (sim, conference) doubled
# conference-REG-games frame `cg` (columns team/opp/outcome).
.pct_vs <- function(cg, team, opps) {
  sub <- cg[cg$team == team & cg$opp %in% opps, ]
  c(sum(sub$outcome), nrow(sub))
}

.keep_max <- function(items, values, tol = 1e-12) {
  items[values >= max(values) - tol]
}

.note_add <- function(notes_env, msg) {
  if (!(msg %in% notes_env$notes)) {
    notes_env$notes <- c(notes_env$notes, msg)
  }
}

# Head-to-head rung: generic (pre-existing, unchanged) vs registry
# multi-team semantics (combined h2h only if every tied pair played;
# otherwise defeated-all elimination only).
.apply_h2h <- function(cands, cg, generic) {
  if (generic || length(cands) == 2L) {
    pn <- lapply(cands, function(c) .pct_vs(cg, c, setdiff(cands, c)))
    ns <- vapply(pn, function(x) x[2], numeric(1))
    if (all(ns > 0)) {
      vals <- vapply(pn, function(x) x[1] / x[2], numeric(1))
      return(.keep_max(cands, vals))
    }
    return(cands)
  }
  pairs_played <- TRUE
  for (a in cands) {
    for (b in cands) {
      if (a != b && .pct_vs(cg, a, b)[2] == 0) pairs_played <- FALSE
    }
  }
  if (pairs_played) {
    vals <- vapply(cands, function(c) {
      pn <- .pct_vs(cg, c, setdiff(cands, c))
      if (pn[2] > 0) pn[1] / pn[2] else 0
    }, numeric(1))
    return(.keep_max(cands, vals))
  }
  for (c in cands) {
    others <- setdiff(cands, c)
    recs <- lapply(others, function(o) .pct_vs(cg, c, o))
    played_all <- all(vapply(recs, function(r) r[2] > 0, logical(1)))
    if (played_all && all(vapply(recs, function(r) r[1] == r[2], logical(1)))) {
      return(c)
    }
  }
  cands
}

# Record vs ALL common conference opponents of the tied set (min 1 shared).
.apply_record_vs_common <- function(cands, cg) {
  if (length(cands) <= 1L) return(cands)
  opp_sets <- lapply(cands, function(t) unique(cg$opp[cg$team == t]))
  common <- setdiff(Reduce(intersect, opp_sets), cands)
  if (length(common) == 0L) return(cands)
  vals <- vapply(cands, function(c) {
    pn <- .pct_vs(cg, c, common)
    if (pn[2] > 0) pn[1] / pn[2] else 0
  }, numeric(1))
  .keep_max(cands, vals)
}

# Descend the conference standings (best to worst) comparing vs each common
# opponent, or tied GROUP of opponents compared collectively (the Big 12
# grouped-ties rule, adopted for every registry descent rung).
.apply_record_vs_common_desc <- function(cands, cg, conf_pct_by_team) {
  others <- setdiff(names(conf_pct_by_team), cands)
  if (length(others) == 0L) return(cands)
  pcts <- round(conf_pct_by_team[others], 9)
  for (p in sort(unique(pcts), decreasing = TRUE)) {
    group <- others[pcts == p]
    pn <- lapply(cands, function(c) .pct_vs(cg, c, group))
    ns <- vapply(pn, function(x) x[2], numeric(1))
    if (all(ns > 0)) {
      vals <- vapply(pn, function(x) x[1] / x[2], numeric(1))
      reduced <- .keep_max(cands, vals)
      if (length(reduced) < length(cands)) return(reduced)
    }
  }
  cands
}

# Dispatch one rung. `metrics` is a named list (by team) of per-team scalar
# metrics precomputed in `standings_add_conf_ranks()`; `ctx` carries
# conference name / conf_pct-by-team / whether `teams$division` is absent.
.apply_rung <- function(cands, rung, metrics, cg, ctx, notes_env) {
  kind <- rung$kind
  if (kind == "h2h") return(.apply_h2h(cands, cg, isTRUE(rung$generic)))
  if (kind == "record_vs_common") return(.apply_record_vs_common(cands, cg))
  if (kind == "record_vs_common_desc") {
    return(.apply_record_vs_common_desc(cands, cg, ctx$conf_pct_by_team))
  }
  if (kind == "sov") {
    return(.keep_max(cands, vapply(cands, function(c) metrics[[c]]$sov, numeric(1))))
  }
  if (kind == "sos") {
    return(.keep_max(cands, vapply(cands, function(c) metrics[[c]]$sos, numeric(1))))
  }
  if (kind == "conf_pd") {
    return(.keep_max(cands, vapply(cands, function(c) metrics[[c]]$conf_pd, numeric(1))))
  }
  if (kind == "opp_conf_win_pct") {
    return(.keep_max(cands, vapply(cands, function(c) metrics[[c]]$opp_wp_pooled, numeric(1))))
  }
  if (kind == "capped_scoring_margin") {
    vals <- vapply(cands, function(c) metrics[[c]]$capped_margin, numeric(1))
    if (anyNA(vals)) {
      .note_add(notes_env, sprintf(
        "%s: capped_scoring_margin skipped (no home_points/away_points on games)",
        ctx$conf_name
      ))
      return(cands)
    }
    return(.keep_max(cands, vals))
  }
  if (kind == "total_wins") {
    if (isTRUE(ctx$division_absent)) {
      .note_add(notes_env, sprintf(
        "%s: total_wins FCS cap not applied (no division column on teams; using uncapped win totals)",
        ctx$conf_name
      ))
    }
    return(.keep_max(cands, vapply(cands, function(c) metrics[[c]]$capped_wins, numeric(1))))
  }
  if (kind == "analytics_rating") {
    vals <- vapply(cands, function(c) metrics[[c]]$analytics_rating, numeric(1))
    if (anyNA(vals)) {
      .note_add(notes_env, sprintf(
        "%s: analytics_rating skipped (no tiebreaker_data$analytics_ratings supplied)",
        ctx$conf_name
      ))
      return(cands)
    }
    return(.keep_max(cands, vals))
  }
  if (kind == "coin_toss") return(sample(sort(cands), 1L))
  cli::cli_abort("Unknown tiebreak rung kind: {.val {kind}}")
}

# Reduce a tied set through `rungs`; a trailing `coin_toss` rung always
# resolves whatever remains (both the generic cascade and every registry
# cascade end with one).
.pick_winner <- function(tied, metrics, cg, rungs, depth, ctx, notes_env) {
  cands <- sort(tied)
  for (rung in rungs) {
    if (length(cands) <= 1L) break
    min_depth <- rung$min_depth
    if (!is.null(min_depth) && depth < min_depth) next
    cands <- .apply_rung(cands, rung, metrics, cg, ctx, notes_env)
  }
  if (length(cands) > 1L) return(sample(sort(cands), 1L))
  cands[[1L]]
}

# Peel one winner at a time from the tied set, restarting the full rung list
# on the shrinking remainder each time - this loop IS the "restart from rung
# 1 with the remaining set" rule for registry conferences (and is exactly
# the pre-registry generic behavior, unchanged).
.order_tied <- function(tied, metrics, cg, rungs, depth, ctx, notes_env) {
  ordered <- character(0)
  remaining <- sort(tied)
  while (length(remaining) > 1L) {
    winner <- .pick_winner(remaining, metrics, cg, rungs, depth, ctx, notes_env)
    ordered <- c(ordered, winner)
    remaining <- setdiff(remaining, winner)
  }
  c(ordered, remaining)
}
