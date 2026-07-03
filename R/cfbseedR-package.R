#' @keywords internal
"_PACKAGE"

#' @importFrom rlang .data %||% :=
#' @importFrom stats rnorm runif setNames
#' @importFrom utils head read.csv
NULL

# Silence R CMD check notes for data-masking variables used in dplyr verbs
utils::globalVariables(c("."))
