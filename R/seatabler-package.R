#' seatabler: a generic R client for SeaTable servers
#'
#' @description seatabler provides a server-agnostic client for SeaTable
#'   databases. A [seatable_connection()] captures a server URL, the environment
#'   variable holding your API token, and an optional workspace; the generic
#'   `seatable_*` functions then query, read, write and cache tables against any
#'   server.
#'
#'   There is no default server and no domain logic. Packages such as fafbseg
#'   and bancr are expected to wrap these functions, binding their own
#'   connection so their users need no configuration.
#'
#' @section Getting started:
#' \preformatted{
#' con <- seatable_connection(
#'   url = "https://cloud.seatable.io/",
#'   token_envvar = "SEATABLE_TOKEN")
#' seatable_query("SELECT * FROM my_table", con = con)
#' }
#'
#' @keywords internal
"_PACKAGE"
