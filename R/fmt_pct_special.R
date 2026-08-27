#' Format Probabilities for Display
#'
#' @description Formats a numeric vector of probabilities as percentage
#'   strings the way simulation summaries want them: values below 1% render as
#'   `"<1%"` and values above 99.9% as `">99.9%"`, so a long-shot never reads
#'   as a flat `0%` and a near-lock never reads as a certain `100%`. Exact 0
#'   and exact 1 are left as `"0%"` and `"100%"`.
#'
#'   Adapted from nflseedR's `fmt_pct_special()`.
#'
#' @param x A numeric vector of probabilities, all between 0 and 1
#'   (`NA` is allowed and returned as `NA`).
#'
#' @return A character vector the same length as `x`.
#'
#' @examples
#' \donttest{
#' fmt_pct_special(c(0, 0.0004, 0.123, 0.5, 0.9994, 1))
#' }
#'
#' @seealso [summary.cfbseedR_simulation()]
#' @export
fmt_pct_special <- function(x) {
  if (!is.vector(x, mode = "numeric")) {
    cli::cli_abort("Argument {.arg x} has to be a numeric vector.")
  }
  finite <- x[!is.na(x)]
  if (any(finite < 0 | finite > 1)) {
    cli::cli_abort(
      "One or more values in {.arg x} are outside the range between 0 and 1."
    )
  }
  rlang::check_installed("scales", "to format probabilities.")

  eps <- sqrt(.Machine$double.eps)
  # Nudge the extremes inward so scales does not round a genuine long-shot to
  # 0% or a genuine near-lock to 100%.
  x[!is.na(x) & x < 0.01 & x > eps] <- 0.009
  x[!is.na(x) & x > 0.999 & (1 - x) > eps] <- 0.9991

  accuracy <- ifelse(!is.na(x) & x >= 0.995, 0.1, 1)
  prefix <- character(length(x))
  prefix[!is.na(x) & x < 0.01 & x > eps] <- "<"
  prefix[!is.na(x) & x > 0.999] <- ">"
  # ... unless the value really is 1, which prints plainly as 100%.
  prefix[!is.na(x) & (1 - x) <= eps] <- ""
  accuracy[!is.na(x) & (1 - x) <= eps] <- 1
  prefix[is.na(prefix)] <- ""
  accuracy[is.na(accuracy)] <- 1

  scales::number(
    x,
    accuracy = accuracy,
    scale = 100,
    prefix = prefix,
    suffix = "%"
  )
}
