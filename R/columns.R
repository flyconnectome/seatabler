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
#' @param cached Whether to use the cached schema (the default). The schema is
#'   memoised for an hour to save a metadata round-trip on every read; pass
#'   `FALSE` to force a refresh after changing the schema outside this session.
#' @details The returned data.frame also carries a `data` list-column with each
#'   column's raw SeaTable metadata (e.g. a select column's `options`, a date
#'   column's `format`), which the read paths use to coerce results and
#'   [seatable_select_options()] uses to list option names.
#' @return A data.frame with `name`, `type`, `rtype`, `data` and (optionally)
#'   `key`.
#' @export
seatable_columns <- function(table, base = NULL, con = default_connection(),
                             include_key = FALSE, cached = TRUE) {
  con <- as_connection(con)
  if (is.null(base) || is.character(base))
    base <- seatable_base(base_name = base, table = table, con = con)
  if (!cached)
    memoise::forget(seatable_columns_memo)
  tidf <- seatable_columns_memo(table, base)
  if (!include_key) tidf$key <- NULL
  tidf
}

# Memoised schema fetch, keyed on (table, base). The base object is itself
# memoised (see seatable_base), so repeated reads within a session share one
# get_metadata() round-trip. Mirrors fafbseg::flytable_columns_memo, including
# the `data` list-column. Unlike the fafbseg/bancr reference this maps `ctime`
# to POSIXct as well as `mtime`: the system `_ctime` column is date-parsed by
# name in st_fix_coltypes regardless, but a user-created ctime-typed column with
# a custom name only parses if its rtype is POSIXct (otherwise the
# curtype==newtype skip fires first). Treating ctime like mtime is deliberate.
seatable_columns_memo <- memoise::memoise(function(table, base) {
  md <- base$get_metadata()
  tablenames <- vapply(md$tables, "[[", character(1), "name")
  if (!table %in% tablenames)
    stop("Table '", table, "' not found in this base.")
  ti <- md$tables[[which(table == tablenames)]]
  fields <- c("key", "name", "type")
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
  tidf$data <- lapply(ti$columns, "[[", "data")
  tidf
}, cache = cachem::cache_mem(max_age = 60^2))
