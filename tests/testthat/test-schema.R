test_that("seatable_add_columns requires name and type columns", {
  expect_error(seatable_add_columns("t", data.frame(name = "a")), "`name` and `type`")
})

test_that("seatable_add_columns adds only the missing columns", {
  con <- seatable_connection(url = "https://example.com/", token_envvar = "NO_TOKEN")
  want <- data.frame(name = c("side", "notes", "id"),
                     type = c("text", "long-text", "number"),
                     stringsAsFactors = FALSE)
  added <- list()
  testthat::with_mocked_bindings(
    seatable_base = function(...) "base",
    seatable_columns = function(...) data.frame(name = "id", type = "number"),
    seatable_add_column = function(table, column_name, column_type, ...) {
      added[[length(added) + 1L]] <<- c(column_name, column_type)
      invisible(NULL)
    },
    {
      todo <- seatable_add_columns("t", want, con = con, progress = FALSE)
      # id already exists, so only side and notes are added
      expect_identical(todo$name, c("side", "notes"))
      expect_length(added, 2L)
      expect_identical(added[[1]], c("side", "text"))
    })
})

test_that("seatable_add_columns is a no-op when nothing is missing", {
  con <- seatable_connection(url = "https://example.com/", token_envvar = "NO_TOKEN")
  called <- FALSE
  testthat::with_mocked_bindings(
    seatable_base = function(...) "base",
    seatable_columns = function(...) data.frame(name = c("a", "b"), type = "text"),
    seatable_add_column = function(...) { called <<- TRUE; invisible(NULL) },
    {
      todo <- seatable_add_columns("t", data.frame(name = "a", type = "text"),
                                   con = con, progress = FALSE)
      expect_identical(nrow(todo), 0L)
      expect_false(called)
    })
})

test_that("seatable_column_type resolves names and rejects unknown ones", {
  skip_if_not(seatable_api_available())
  enum <- seatabler:::seatable_column_type("text")
  expect_s3_class(enum, "python.builtin.object")
  # Already an enum member: passed through untouched.
  expect_identical(seatabler:::seatable_column_type(enum), enum)
  expect_error(seatabler:::seatable_column_type("no-such-type"), "Unknown SeaTable")
})
