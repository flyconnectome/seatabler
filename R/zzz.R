.onLoad <- function(libname, pkgname) {
  op <- options()
  defaults <- list(
    seatabler.token_envvar = "SEATABLE_TOKEN"
    # seatabler.url and seatabler.workspace_id intentionally have no default:
    # there is no default server.
    # seatabler.cachedir is resolved lazily when caching is added.
  )
  toset <- !(names(defaults) %in% names(op))
  if (any(toset)) options(defaults[toset])
  invisible()
}
