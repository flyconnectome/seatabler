# SeaTable "big data" storage.
#
# A base has a row limit; beyond it, rows must be moved into big data storage,
# where they stay queryable by SQL but leave the interactive grid. Neither
# direction is in the Python SDK, so both go through the API gateway.
# Ported from bancr's banctable_move_to_bigdata().

#' Move rows into and out of SeaTable big data storage
#'
#' @description SeaTable caps the number of rows a base holds in its ordinary
#'   grid; archiving moves rows into "big data" storage, which is much larger
#'   and still queryable with [seatable_query()], at the cost of no longer being
#'   editable in the web interface. `seatable_archive_rows()` moves rows out of
#'   the grid, `seatable_unarchive_rows()` brings them back.
#'
#' @details The two directions select rows differently, because the API does.
#'   Archiving takes a **view**: make a view holding exactly the rows you want
#'   archived (a filtered view is the usual way) and name it. Earlier versions
#'   of the endpoint accepted a SQL `WHERE` clause; that is gone, and a view is
#'   now the only way to choose rows. Unarchiving instead takes explicit
#'   `row_ids`, which you can get by querying the archived rows with
#'   `seatable_query("SELECT _id FROM ...")`.
#'
#'   Archiving is not easily undone in bulk — you need the row ids to bring rows
#'   back — so check the view holds what you expect before calling.
#'
#' @param table Name of the table.
#' @param view_name Name of the view whose rows should be archived. Supply
#'   exactly one of `view_name` or `view_id`.
#' @param view_id Id of the view whose rows should be archived.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#'
#' @return The SeaTable response, invisibly.
#' @export
#' @examples
#' \dontrun{
#' # Archive everything in the (filtered) view called "to archive"
#' seatable_archive_rows("neurons", view_name = "to archive", con = con)
#'
#' # ...and bring two rows back
#' seatable_unarchive_rows("neurons",
#'   row_ids = c("FoDxhChYQSycLm88JZ11RA", "Yb3kQ0rRQ0aXk3lWk0mWLQ"),
#'   con = con)
#' }
seatable_archive_rows <- function(table, view_name = NULL, view_id = NULL,
                                  base = NULL, con = default_connection()) {
  if (is.null(view_name) == is.null(view_id))
    stop("Supply exactly one of `view_name` or `view_id`: SeaTable archives ",
         "the rows of a view, and no longer accepts a WHERE clause.")
  body <- list(table_name = table)
  if (!is.null(view_name)) body$view_name <- view_name else body$view_id <- view_id
  invisible(seatable_base_rest("archive-view/", base = base, table = table,
                               con = con, method = "POST", body = body))
}

#' @rdname seatable_archive_rows
#' @param row_ids Character vector of row ids (the `_id` column) to unarchive.
#' @export
seatable_unarchive_rows <- function(table, row_ids, base = NULL,
                                    con = default_connection()) {
  if (!length(row_ids)) stop("`row_ids` is empty: nothing to unarchive.")
  # The endpoint calls this field table_id, but takes the table name.
  body <- list(table_id = table, row_ids = as.list(as.character(row_ids)))
  invisible(seatable_base_rest("unarchive/", base = base, table = table,
                               con = con, method = "POST", body = body))
}
