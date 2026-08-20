# Offline tests for the non-SQL read paths. The SQL-building in
# seatable_list_selected and the dry-run branch of seatable_delete_rows need no
# server; seatable_query is mocked to capture the SQL it is handed. list_rows
# itself is a thin SDK loop and is exercised by the live tests.

dummy_con <- function()
  seatable_connection(url = "https://example.com/", token_envvar = "NO_TOKEN")

test_that("ids2sqlin builds an IN() clause, quoting unless told not to", {
  expect_match(seatabler:::ids2sqlin(c("a", "b")), "^IN \\(.a.,.b.\\)$")
  expect_identical(seatabler:::ids2sqlin(c(1, 2), quote = FALSE), "IN (1,2)")
})

test_that("seatable_list_selected builds IN() SQL and quotes by column type", {
  captured <- NULL
  fake_query <- function(sql, ...) { captured <<- sql; data.frame() }

  testthat::with_mocked_bindings(
    seatable_query = fake_query,
    st_col_type = function(col, table, base = NULL, con = NULL) "character",
    {
      seatable_list_selected(ids = c("a", "b"), table = "t",
                             idfield = "name", con = dummy_con())
    })
  expect_match(captured, "select \\* from t where name IN \\(.a.,.b.\\)")

  # a numeric id column is left unquoted
  testthat::with_mocked_bindings(
    seatable_query = fake_query,
    st_col_type = function(col, table, base = NULL, con = NULL) "numeric",
    {
      seatable_list_selected(ids = c(1, 2), table = "t", idfield = "uid",
                             con = dummy_con())
    })
  expect_match(captured, "where uid IN \\(1,2\\)")
})

test_that("seatable_list_selected back-quotes a vector of fields and needs idfield", {
  captured <- NULL
  testthat::with_mocked_bindings(
    seatable_query = function(sql, ...) { captured <<- sql; data.frame() },
    {
      seatable_list_selected(ids = NULL, table = "t", fields = c("a", "b"),
                             con = dummy_con())
    })
  expect_match(captured, "select `a`,`b` from t")

  expect_error(
    seatable_list_selected(ids = 1, table = "t", con = dummy_con()),
    "Supply .idfield")
})

test_that("seatable_delete_rows dry run is offline, dedups, and reads _id", {
  expect_identical(
    seatable_delete_rows(c("x", "x", "y"), table = "t", con = dummy_con()),
    c("x", "y"))
  df <- data.frame(`_id` = c("a", "b"), v = 1:2, check.names = FALSE)
  expect_identical(seatable_delete_rows(df, table = "t", con = dummy_con()),
                   c("a", "b"))
  expect_error(
    seatable_delete_rows(character(0), table = "t", con = dummy_con()),
    "No ids")
})
