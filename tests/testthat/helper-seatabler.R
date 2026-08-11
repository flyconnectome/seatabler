# Is the seatable_api Python package importable? Tests that touch the SDK are
# skipped without it, so the suite still runs on a machine with no Python.
seatable_api_available <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    !inherits(try(reticulate::import("seatable_api"), silent = TRUE), "try-error")
}
