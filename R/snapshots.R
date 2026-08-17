# Base snapshots.
#
# SeaTable takes periodic snapshots of a base, which are the only route back
# from a bad bulk write. Listing them from R makes that recovery discoverable
# rather than something you go hunting for in the web UI.
# Ported from bancr's banctable_snapshots().

#' List the snapshots of a SeaTable base
#'
#' @description SeaTable snapshots a base periodically, and a snapshot is the
#'   only way back from a bad bulk update. This lists the snapshots available
#'   for a base, so you can see how far back you can go and pick the one to
#'   restore from in the web interface.
#'
#' @details Restoring is deliberately not wrapped: it is destructive, has no
#'   undo, and belongs in the SeaTable UI where it asks for confirmation.
#'
#' @param base_name Name of the base.
#' @param con A [seatable_connection].
#' @param workspace_id Workspace holding the base. Defaults to the connection's
#'   `workspace_id`, or is looked up with [seatable_workspace_id()].
#'
#' @return A data frame of snapshots, one row each, typically with the snapshot
#'   name and its creation time. An empty data frame when the base has none.
#' @export
#' @examples
#' \dontrun{
#' seatable_snapshots("my_base", con = con)
#' }
seatable_snapshots <- function(base_name, con = default_connection(),
                               workspace_id = NULL) {
  con <- as_connection(con)
  if (is.null(workspace_id))
    workspace_id <- seatable_workspace_id(base_name, con = con)
  path <- sprintf("api/v2.1/workspace/%s/dtable/%s/snapshots/",
                  workspace_id, utils::URLencode(base_name, reserved = TRUE))
  res <- seatable_rest(path, con = con)
  snapshots <- res$snapshot_list
  if (!length(snapshots)) return(data.frame())
  dplyr::bind_rows(lapply(snapshots, function(x)
    as.data.frame(lapply(x, function(v) if (is.null(v)) NA else v),
                  stringsAsFactors = FALSE)))
}
