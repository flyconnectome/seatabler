# Base (≈ database) resolution.
#
# A SeaTable "base" groups tables. To reach one we need its workspace id. The
# connection may carry a workspace_id; otherwise we discover it from the base
# name (or, given only a table name, by scanning bases).
#
# Ported from fafbseg's flytable_base* and generalised to take a connection.

#' Get a SeaTable base object
#'
#' @param base_name Name of the base. Optional if `table` is supplied and unique
#'   across the server.
#' @param table Name of a table whose base you want. Used to discover the base
#'   when `base_name` is not given.
#' @param con A [seatable_connection].
#' @param workspace_id Workspace id. Defaults to the connection's `workspace_id`;
#'   discovered from `base_name` when `NULL`.
#' @param cached Whether to use the memoised base object.
#' @importFrom cachem cache_mem
#' @return A Python SeaTable `Base` object (reticulate-wrapped).
#' @export
seatable_base <- function(base_name = NULL, table = NULL,
                          con = default_connection(),
                          workspace_id = con$workspace_id,
                          cached = TRUE) {
  con <- as_connection(con)
  if (!cached) memoise::forget(seatable_base_impl)
  base <- try(seatable_base_impl(base_name = base_name, table = table,
                                 con = con, workspace_id = workspace_id),
              silent = TRUE)
  # Retry uncached if the cached object failed or the token looks near-expiry.
  stale <- isTRUE(try(difftime(base$jwt_exp, Sys.time(), units = "hours") < 1,
                      silent = TRUE))
  if ((cached && inherits(base, "try-error")) || stale) {
    memoise::forget(seatable_base_impl)
    base <- seatable_base_impl(base_name = base_name, table = table,
                               con = con, workspace_id = workspace_id)
  }
  base
}

seatable_base_impl <- memoise::memoise(function(base_name = NULL, table = NULL,
                                                con, workspace_id = NULL) {
  ac <- seatable_login(con = con)
  if (is.null(base_name) && is.null(table))
    stop("You must supply one of `base_name` or `table`.")
  if (is.null(base_name)) {
    # discover base from table name
    tdf <- seatable_alltables(con = con)
    sel <- tdf[tdf$name == table, , drop = FALSE]
    if (nrow(sel) == 0) stop("Unable to find a table named: ", table)
    if (nrow(sel) > 1)
      stop("Multiple tables named: ", table, ". Supply `base_name` too.")
    base_name <- sel$base_name
    workspace_id <- sel$workspace_id
  }
  if (is.null(workspace_id))
    workspace_id <- seatable_workspace_id(base_name, con = con)
  reticulate::py_call(ac$get_base, workspace_id = workspace_id,
                      base_name = base_name)
}, cache = cache_mem(max_age = 3 * 24 * 60^2))

#' List workspaces (and their bases) visible to a connection
#'
#' @param con A [seatable_connection].
#' @return A data.frame with at least `workspace_id` and base `name` columns.
#' @export
seatable_workspaces <- function(con = default_connection()) {
  con <- as_connection(con)
  ac <- seatable_login(con = con)
  ws <- ac$list_workspaces()
  wl <- lapply(ws$workspace_list, "[[", "table_list")
  wsl <- lapply(ws$workspace_list, "[[", "shared_table_list")
  wsdf <- dplyr::bind_rows(wl[lengths(wl) > 0])
  wsdf2 <- dplyr::bind_rows(wsl[lengths(wsl) > 0])
  wsdf <- dplyr::bind_rows(wsdf, wsdf2)
  wsdf[!duplicated(wsdf[c("workspace_id", "name")]), , drop = FALSE]
}

#' Find the workspace containing a base
#'
#' @description Resolves the workspace id for a named base. Some SeaTable REST
#'   endpoints (snapshots, for instance) are addressed by workspace rather than
#'   by base uuid, and users rarely know their workspace ids.
#'
#' @param base_name Name of the base.
#' @param con A [seatable_connection]. When the connection already carries a
#'   `workspace_id` that is returned unchanged.
#' @return The workspace id, as a character string.
#' @export
seatable_workspace_id <- function(base_name, con = default_connection()) {
  con <- as_connection(con)
  if (!is.null(con$workspace_id)) return(as.character(con$workspace_id))
  wsdf <- seatable_workspaces(con = con)
  sel <- wsdf[wsdf$name == base_name, , drop = FALSE]
  sel <- sel[!duplicated(sel$workspace_id), , drop = FALSE]
  if (nrow(sel) == 0)
    stop("Unable to find a workspace containing base: ", base_name,
         "\nCheck the base name and your access permissions.")
  if (nrow(sel) > 1)
    stop("Multiple workspaces contain base: ", base_name,
         "\nSpecify `workspace_id` to resolve the ambiguity.")
  as.character(sel$workspace_id)
}

#' List all tables across all bases visible to a connection
#'
#' @param con A [seatable_connection].
#' @return A data.frame with `base_name`, `workspace_id`, table `name` and `_id`.
#' @export
seatable_alltables <- function(con = default_connection()) {
  con <- as_connection(con)
  wsdf <- seatable_workspaces(con = con)
  if (is.null(wsdf) || nrow(wsdf) == 0) return(NULL)
  ll <- lapply(seq_len(nrow(wsdf)), function(i) {
    base <- seatable_base(base_name = wsdf$name[i],
                          workspace_id = wsdf$workspace_id[i],
                          con = con, cached = FALSE)
    md <- base$get_metadata()
    tt <- dplyr::bind_rows(lapply(md$tables, function(x)
      as.data.frame(x[c("name", "_id")], check.names = FALSE)))
    cbind(data.frame(base_name = wsdf$name[i],
                     workspace_id = wsdf$workspace_id[i],
                     stringsAsFactors = FALSE), tt)
  })
  dplyr::bind_rows(ll)
}
