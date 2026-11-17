tidf <- data.frame(
  name = c("id", "label", "tags"),
  type = c("number", "text", "multiple-select"),
  rtype = c("numeric", "character", "character"),
  stringsAsFactors = FALSE)

test_that("st_coerce_df comma-joins multi-valued cells and NAs empties", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), "c", character(0))
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_equal(out$tags, c("a,b", "c", NA))
  expect_type(out$tags, "character")
})

test_that("st_coerce_df honours a custom separator", {
  df <- data.frame(id = 1L, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"))
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = "; ")
  expect_equal(out$tags, "a; b")
})

test_that("st_coerce_df keeps list-columns when collapse = FALSE", {
  df <- data.frame(id = 1:2, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), "c")
  expect_warning(
    out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = FALSE),
    "cannot be vectorised")
  expect_true(is.list(out$tags))
})

test_that("st_coerce_df treats a scalar NA multi-select cell as empty", {
  # pandas fills a multiple-select column with float NaN for missing cells when
  # only some rows in a batch have a value -- that must read as empty, not "NaN".
  df <- data.frame(id = 1:2, stringsAsFactors = FALSE)
  df$tags <- list(c("a", "b"), NA)
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_equal(out$tags, c("a,b", NA))

  # without the schema it cannot know `tags` is multi-select, so the scalar NA
  # is collapsed like any value and stringifies to a literal "NA" -- exactly the
  # bug the schema-aware path above prevents.
  out2 <- seatabler:::st_coerce_df(df, tidf = NULL, collapse = TRUE)
  expect_equal(out2$tags, c("a,b", "NA"))
})

test_that("st_coerce_df unlists an all-length-1 list column", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list("a", "b", "c")
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$tags, c("a", "b", "c"))
})

test_that("st_coerce_df maps length-0/1 columns to a char vector with NA", {
  df <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  df$tags <- list("a", character(0), "c")
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$tags, c("a", NA, "c"))
})

test_that("st_coerce_df leaves non-list columns untouched when types match", {
  df <- data.frame(id = 1:2, label = c("x", "y"), stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tidf, collapse = TRUE)
  expect_identical(out$id, 1:2)
  expect_identical(out$label, c("x", "y"))
})

test_that("st_coerce_df applies SeaTable column types (fix_coltypes)", {
  # list_rows returns everything as strings; the schema restores R types
  df <- data.frame(n = c("1", "2", "3"), flag = c("True", "", "True"),
                   note = c("a", "b", "c"), stringsAsFactors = FALSE)
  tt <- data.frame(name = c("n", "flag", "note"),
                   type = c("number", "checkbox", "text"),
                   rtype = c("numeric", "logical", "character"),
                   stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tt)
  expect_identical(out$n, c(1, 2, 3))
  expect_type(out$flag, "logical")
  expect_identical(out$note, c("a", "b", "c"))
})

test_that("st_coerce_df parses timestamp columns to POSIXt", {
  df <- data.frame(`_mtime` = c("2021-06-23T07:01:00+00:00",
                                "2022-01-12T09:30:00+00:00"),
                   check.names = FALSE, stringsAsFactors = FALSE)
  tt <- data.frame(name = "_mtime", type = "mtime", rtype = "POSIXct",
                   stringsAsFactors = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tt)
  expect_s3_class(out$`_mtime`, "POSIXt")
  expect_false(anyNA(out$`_mtime`))
})

test_that("st_coerce_df is a no-op on a zero-column frame", {
  df <- data.frame()
  expect_identical(seatabler:::st_coerce_df(df), df)
})

test_that("st_coerce_df leaves columns absent from the schema alone", {
  # e.g. a COUNT(_id) result column not present in tidf
  df <- data.frame(`COUNT(_id)` = 42L, check.names = FALSE)
  out <- seatabler:::st_coerce_df(df, tidf = tidf)
  expect_identical(out[["COUNT(_id)"]], 42L)
})

# ---- st_parse_date --------------------------------------------------------

sp <- function(...) seatabler:::st_parse_date(...)

test_that("st_parse_date uses the column's declared format", {
  # "YYYY-MM-DD HH:mm" -> date + time
  t <- sp("2021-06-23 07:01", colinfo = list(format = "YYYY-MM-DD HH:mm"))
  expect_s3_class(t, "POSIXt")
  expect_identical(format(t, tz = "UTC"), "2021-06-23 07:01:00")
  # "YYYY-MM-DD" -> date only
  d <- sp("2021-06-23", colinfo = list(format = "YYYY-MM-DD"))
  expect_s3_class(d, "POSIXt")
  expect_identical(format(d, tz = "UTC"), "2021-06-23")
})

test_that("st_parse_date warns and passes through an unrecognised format", {
  expect_warning(out <- sp("x", colinfo = list(format = "DD/MM/YYYY")),
                 "Unrecognised date format")
  expect_identical(out, "x")
})

test_that("st_parse_date guesses the format from the values", {
  # bare date
  expect_identical(format(sp("2021-06-23"), tz = "UTC"), "2021-06-23")
  # ISO with a trailing Z (GMT) -> strips Z/T and parses to the second
  expect_identical(format(sp("2022-01-12T09:30:00Z"), tz = "UTC"),
                   "2022-01-12 09:30:00")
  # ISO with a numeric offset (T but no Z) -> timestamp format with %z
  expect_identical(format(sp("2021-06-23T07:01:00+00:00"), tz = "UTC"),
                   "2021-06-23 07:01:00")
  # space-separated to the minute
  expect_identical(format(sp("2021-06-23 07:01"), tz = "UTC"),
                   "2021-06-23 07:01:00")
})

test_that("st_parse_date warns on empty and unparseable columns", {
  expect_warning(out <- sp(c(NA, "")), "cannot parse empty date column")
  expect_identical(out, c(NA, ""))
  expect_warning(out2 <- sp(c("foo", "bar")), "Unrecognised date format")
  expect_identical(out2, c("foo", "bar"))
})

test_that("st_parse_date has a base-R fallback when lubridate is off", {
  # lubridate = FALSE forces strptime; the tz colon is stripped for %z
  out <- sp("2021-06-23T07:01:00+00:00", lubridate = FALSE)
  expect_s3_class(out, "POSIXt")
  expect_identical(format(out, tz = "UTC"), "2021-06-23 07:01:00")
})

test_that("st_parse_date reads ISO date cells as UTC wall-clock time", {
  # the server tags stored wall-clock values with its local offset (BST/GMT),
  # often mixed in one column; writers sent UTC, so the offset is ignored
  x <- c("2022-04-26T22:12:00+01:00", "2022-09-30T20:19:00Z",
         "2024-05-20T02:02:00+00:00", "2025-10-04T11:30:16.642+01:00",
         "2024-05-20T02:02", "2021-06-23 07:01", NA)
  want <- c("2022-04-26 22:12:00", "2022-09-30 20:19:00", "2024-05-20 02:02:00",
            "2025-10-04 11:30:16", "2024-05-20 02:02:00", "2021-06-23 07:01:00",
            NA)
  for (lub in c(TRUE, FALSE)) {
    skip_if(lub && !requireNamespace("lubridate", quietly = TRUE))
    for (ci in list(NULL, list(format = "YYYY-MM-DD HH:mm"))) {
      out <- sp(x, colinfo = ci, lubridate = lub)
      expect_s3_class(out, "POSIXt")
      expect_identical(format(out, "%Y-%m-%d %H:%M:%S", tz = "UTC"), want)
    }
  }
})

test_that("date-only columns keep the calendar date across zone offsets", {
  # local midnight in BST / CEST would fall on the previous day in UTC
  x <- c("2026-08-18T00:00:00+02:00", "2025-02-08T00:00:00+01:00",
         "2025-10-19T00:00:00Z", "2021-06-23", NA)
  for (lub in c(TRUE, FALSE)) {
    skip_if(lub && !requireNamespace("lubridate", quietly = TRUE))
    out <- sp(x, colinfo = list(format = "YYYY-MM-DD"), lubridate = lub)
    expect_s3_class(out, "POSIXt")
    expect_identical(format(out, "%Y-%m-%d %H:%M", tz = "UTC"),
                     c("2026-08-18 00:00", "2025-02-08 00:00",
                       "2025-10-19 00:00", "2021-06-23 00:00", NA))
  }
})

test_that("system timestamps honour their zone offset", {
  # _mtime / now() are server instants, e.g. across the BST/GMT change
  x <- c("2025-10-04T11:30:16.642+01:00", "2025-02-18T14:23:42.771Z",
         "2026-11-14T14:38:40.512838387Z", "2026-03-29T01:30:00+00:00",
         "2026-03-29T03:30:00+01:00", NA)
  for (lub in c(TRUE, FALSE)) {
    skip_if(lub && !requireNamespace("lubridate", quietly = TRUE))
    out <- sp(x, format = "timestamp", lubridate = lub)
    expect_identical(format(out, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
                     c("2025-10-04 10:30:16", "2025-02-18 14:23:42",
                       "2026-11-14 14:38:40", "2026-03-29 01:30:00",
                       "2026-03-29 02:30:00", NA))
  }
})
