# Authentication / Python SDK bootstrap.
#
# seatabler talks to SeaTable via the official `seatable_api` Python package
# through reticulate. Python-environment *management* is deliberately out of
# scope (that belongs in a consumer such as fafbseg::simple_python). Here we only
# import the package and give install guidance if it is missing.

#' Check that the seatable_api Python package is available
#'
#' @description Imports the `seatable_api` Python module via reticulate. seatabler
#'   does **not** manage Python environments itself; instead it declares the
#'   requirement and, on a failed import, tries in order: (1) a
#'   consumer-registered provisioner (see details), (2) an interactive
#'   `reticulate::py_install()` into the environment reticulate is already using,
#'   before finally erroring with guidance. Memoised so the import cost is paid
#'   once per session.
#'
#' @details **Ecosystem integration without a dependency.** A package that
#'   manages its own Python environment (e.g. fafbseg, via `simple_python()`) can
#'   register a provisioner so seatabler installs `seatable_api` into *that*
#'   environment rather than guessing. Register a zero-argument function via the
#'   `seatabler.python_provisioner` option — typically in the consumer's
#'   `.onLoad()`:
#'
#'   \preformatted{
#'   # in fafbseg .onLoad():
#'   options(seatabler.python_provisioner = function()
#'     fafbseg::simple_python(pkgs = "seatable_api"))
#'   }
#'
#'   Because fafbseg depends on seatabler (not the other way round) it can set
#'   this hook, giving seatabler access to `simple_python` without seatabler
#'   depending on fafbseg. Standalone users need no hook — they get the
#'   interactive `py_install()` fallback, or can install `seatable_api`
#'   themselves.
#'
#' @return The imported `seatable_api` module.
#' @export
check_seatable <- local({
  memoised <- NULL
  function() {
    if (!is.null(memoised)) return(memoised)
    if (!requireNamespace("reticulate", quietly = TRUE))
      stop("The 'reticulate' package is required to use seatabler.")
    import_st <- function() tryCatch(reticulate::import("seatable_api"),
                                     error = function(e) NULL)
    st <- import_st()

    # 1. Consumer-registered provisioner (e.g. fafbseg's simple_python), so the
    #    package lands in whatever env that consumer manages.
    if (is.null(st)) {
      prov <- getOption("seatabler.python_provisioner")
      if (is.function(prov)) {
        try(prov(), silent = TRUE)
        st <- import_st()
      }
    }

    # 2. Interactive fallback: install into the env reticulate is already bound
    #    to. Only with consent, since it mutates the user's Python environment.
    if (is.null(st) && interactive()) {
      ans <- readline("Install the Python 'seatable_api' package now (y/n)? ")
      if (tolower(trimws(ans)) %in% c("y", "yes")) {
        try(reticulate::py_install("seatable_api"), silent = TRUE)
        st <- import_st()
      }
    }

    if (is.null(st))
      stop(call. = FALSE,
           "Could not import the Python 'seatable_api' package.\n",
           "Install it into the Python environment reticulate is using, e.g.\n",
           "  reticulate::py_install('seatable_api')\n",
           "or, if you use fafbseg, fafbseg::simple_python(pkgs = 'seatable_api').\n",
           "Packages that manage their own Python env can also register a ",
           "provisioner via options(seatabler.python_provisioner = ...); ",
           "see ?check_seatable.")
    memoised <<- st
    st
  }
})

#' Log in to a SeaTable server
#'
#' @param con A [seatable_connection].
#' @return A Python SeaTable `Account` object (reticulate-wrapped), invisibly.
#' @export
#' @examples
#' \dontrun{
#' con <- seatable_connection("https://cloud.seatable.io/", "BANCTABLE_TOKEN")
#' seatable_login(con)
#' }
seatable_login <- function(con = default_connection()) {
  con <- as_connection(con)
  st <- check_seatable()
  token <- seatable_token(con)  # errors if unset
  ac <- reticulate::py_call(st$Account, login_name = NULL, password = NULL,
                            server_url = con$url)
  ac$token <- token
  invisible(ac)
}

#' Obtain and display a SeaTable API token
#'
#' @description Uses your SeaTable user name and password to obtain a permanent
#'   user-level API token, then tells you how to store it in the connection's
#'   `token_envvar`. Unlike the fafbseg original, this does **not** silently
#'   append to `~/.Renviron`; it prints the line so you can decide where to keep
#'   it.
#'
#' @param user,pwd SeaTable user name (email) and password.
#' @param con A [seatable_connection].
#' @return The token string, invisibly.
#' @export
seatable_set_token <- function(user, pwd, con = default_connection()) {
  con <- as_connection(con)
  st <- check_seatable()
  ac <- reticulate::py_call(st$Account, login_name = user, password = pwd,
                            server_url = con$url)
  ac$auth()
  token <- ac$token
  do.call(Sys.setenv, structure(list(token), names = con$token_envvar))
  message("Obtained a token and set ", con$token_envvar, " for this session.\n",
          "To persist it, add this line to ~/.Renviron:\n",
          con$token_envvar, "='", token, "'")
  invisible(token)
}
