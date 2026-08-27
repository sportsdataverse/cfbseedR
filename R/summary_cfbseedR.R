#' Compute a Pretty Simulation Summary Table
#'
#' @description Renders the `overall` table of a [cfb_simulations()] result as
#'   a gt table, one row group per conference, sorted by average wins.
#'   Probabilities are formatted with [fmt_pct_special()] so long-shots and
#'   near-locks stay readable.
#'
#'   The CFB counterpart of nflseedR's `summary.nflseedR_simulation()`; the
#'   layout is conference-grouped rather than nflseedR's AFC/NFC pair of
#'   columns, because college conferences are neither two nor equally sized.
#'
#' @param object A `cfbseedR_simulation` object, as returned by
#'   [cfb_simulations()].
#' @param ... Additional arguments (currently unused).
#'
#' @return A `gt_tbl` object.
#'
#' @examples
#' \donttest{
#' games <- cfb_games_example
#' games$result[games$week >= 3] <- NA
#' set.seed(4)
#' sim <- cfb_simulations(games, cfb_teams_example,
#'                        simulations = 4, playoff_seeds = 4, chunks = 1)
#' summary(sim)
#' }
#'
#' @seealso [cfb_simulations()], [fmt_pct_special()]
#' @export
summary.cfbseedR_simulation <- function(object, ...) {
  rlang::check_installed(
    c("gt (>= 0.9.0)", "scales (>= 1.2.0)"),
    "to compute a summary table."
  )

  season <- object$sim_params$cfb_season
  n_sims <- object$sim_params$simulations

  tbl <- object$overall
  # Independents have no conference to group under; give them their own group
  # rather than dropping them from the summary entirely.
  tbl$conference <- ifelse(
    is.na(tbl$conference) | tbl$conference == "",
    "Independent", tbl$conference
  )
  tbl <- tbl[order(tbl$conference, -tbl$wins, -tbl$playoff), ]

  # Drop all-NA probability columns (won_natty is NA when sim_include = "REG").
  keep <- vapply(tbl, function(col) !all(is.na(col)), logical(1))
  tbl <- tbl[, names(keep)[keep], drop = FALSE]

  pct_cols <- intersect(
    c("conf_champ", "playoff", "seed1", "won_natty"), names(tbl)
  )

  out <- gt::gt(tbl, groupname_col = "conference")
  out <- gt::cols_label(
    out,
    team = "",
    wins = gt::html("AVG.<br>WINS")
  )
  labels <- list(
    conf_champ = gt::html("Win<br>CONF"),
    playoff = gt::html("Make<br>CFP"),
    seed1 = gt::html("No.1<br>Seed"),
    won_natty = gt::html("Win<br>NATTY")
  )
  for (col in pct_cols) {
    out <- gt::cols_label(out, .list = stats::setNames(labels[col], col))
  }
  out <- gt::fmt_number(out, columns = "wins", decimals = 1)
  out <- gt::text_transform(
    out,
    locations = gt::cells_body(columns = gt::all_of(pct_cols)),
    fn = function(x) fmt_pct_special(as.numeric(x))
  )
  out <- gt::tab_header(
    out,
    title = paste("Simulating the", season, "college football season"),
    subtitle = paste(
      "summary of",
      scales::number(n_sims, scale_cut = scales::cut_short_scale()),
      "simulations using cfbseedR"
    )
  )
  out <- gt::tab_options(
    out,
    row_group.font.weight = "bold",
    column_labels.font.weight = "bold",
    table.font.size = gt::px(13)
  )
  gt::cols_align(out, align = "center", columns = c("wins", pct_cols))
}
