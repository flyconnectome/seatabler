# Column metadata.

#' Column names, types and default R types for a table
#'
#' @param table Table name.
#' @param base Optional base name or `Base` object; discovered from `table` when
#'   `NULL`.
#' @param con A [seatable_connection].
#' @param include_key Whether to include the internal SeaTable column `key`
#'   (useful for schema operations and for debugging API errors that reference
#'   keys). Defaults to `FALSE`.
#' @return A data.frame with `name`, `type`, `rtype` and (optionally) `key`.
#' @export
seatable_columns <- function(table, base = NULL, con = default_connection(),
                             include_key = FALSE) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  md <- base$get_metadata()
  tablenames <- vapply(md$tables, "[[", character(1), "name")
  if (!table %in% tablenames)
    stop("Table '", table, "' not found in this base.")
  ti <- md$tables[[which(table == tablenames)]]
  fields <- if (include_key) c("key", "name", "type") else c("name", "type")
  tidf <- dplyr::bind_rows(lapply(ti$columns, function(x) {
    vals <- x[fields]
    vals[vapply(vals, is.null, logical(1))] <- NA_character_
    as.data.frame(vals, stringsAsFactors = FALSE, check.names = FALSE)
  }))
  tidf$rtype <- vapply(tidf$type, function(ty) switch(ty,
    number = "numeric",
    checkbox = "logical",
    date = "POSIXct",
    mtime = "POSIXct",
    ctime = "POSIXct",
    "character"), character(1))
  tidf
}
