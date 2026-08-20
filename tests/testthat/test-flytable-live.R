# Live test against the public-ish `testfruit` table on the LMB flytable server,
# borrowed from fafbseg's test-flytable.R. It needs the seatable_api Python
# package and a FLYTABLE_TOKEN (a repository secret in CI); it skips gracefully
# when either is missing, so it is a no-op on a machine without Python or a token.

flytable_test_connection <- function() {
  seatable_connection(url = "https://flytable.mrc-lmb.cam.ac.uk/",
                      token_envvar = "FLYTABLE_TOKEN",
                      workspace_id = "5", name = "flytable-test")
}

# Shared skip guards + login; returns a logged-in connection or skips the test.
flytable_test_con_or_skip <- function() {
  skip_on_cran()
  skip_if_not(seatable_api_available(), "seatable_api Python package not available")
  skip_if(!nzchar(Sys.getenv("FLYTABLE_TOKEN")), "FLYTABLE_TOKEN not set")
  con <- flytable_test_connection()
  ac <- try(seatable_login(con = con), silent = TRUE)
  skip_if(inherits(ac, "try-error"), "unable to log in to flytable")
  con
}

test_that("live query against flytable testfruit works", {
  skip_on_cran()
  skip_if_not(seatable_api_available(), "seatable_api Python package not available")
  skip_if(!nzchar(Sys.getenv("FLYTABLE_TOKEN")), "FLYTABLE_TOKEN not set")

  con <- flytable_test_connection()
  ac <- try(seatable_login(con = con), silent = TRUE)
  skip_if(inherits(ac, "try-error"), "unable to log in to flytable")

  # Name the base (`test`) and workspace so we skip the slow all-workspace scan.
  df <- try(seatable_query(
    "select fruit_name, person, nid, _ctime FROM testfruit WHERE nid<=3",
    limit = 3L, base = "test", con = con, progress = FALSE), silent = TRUE)
  skip_if(inherits(df, "try-error") || is.null(df),
          "testfruit query failed (service issue)")

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 3L)
  expect_true(all(c("fruit_name", "person", "nid") %in% names(df)))
  expect_type(df$fruit_name, "character")
  # Small integer columns come back as base R integer (nat.python::pandas2df
  # maps small ints onto integer rather than reserving bit64 for them).
  expect_type(df$nid, "integer")
  expect_equal(sort(df$nid), 1:3)

  # python = TRUE hands back the live pandas DataFrame untouched.
  pdd <- try(seatable_query("select nid FROM testfruit WHERE nid<=3",
                            limit = 3L, base = "test", con = con,
                            python = TRUE), silent = TRUE)
  skip_if(inherits(pdd, "try-error"), "python=TRUE query failed (service issue)")
  expect_true(inherits(pdd, "python.builtin.object"))
})

test_that("live seatable_list_rows reads and paginates testfruit", {
  con <- flytable_test_con_or_skip()

  fruit <- try(seatable_list_rows("testfruit", base = "test", con = con),
               silent = TRUE)
  skip_if(inherits(fruit, "try-error") || is.null(fruit),
          "testfruit list_rows failed (service issue)")
  expect_s3_class(fruit, "data.frame")
  expect_true(all(c("fruit_name", "person", "nid") %in% names(fruit)))
  skip_if(nrow(fruit) < 3, "testfruit has too few rows for the pagination check")

  # A limited read and a chunked limited read must agree: same server order,
  # so forcing tiny pages must not change the rows returned.
  top3 <- try(seatable_list_rows("testfruit", base = "test", con = con, limit = 3),
              silent = TRUE)
  paged <- try(seatable_list_rows("testfruit", base = "test", con = con,
                                  limit = 3, chunksize = 2), silent = TRUE)
  skip_if(inherits(top3, "try-error") || inherits(paged, "try-error"),
          "limited list_rows failed (service issue)")
  expect_equal(nrow(top3), 3L)
  expect_equal(top3, paged)

  # python = TRUE returns the concatenated pandas DataFrame, even when chunked.
  pdd <- try(seatable_list_rows("testfruit", base = "test", con = con,
                                limit = 3, chunksize = 2, python = TRUE),
             silent = TRUE)
  skip_if(inherits(pdd, "try-error"), "python=TRUE list_rows failed (service issue)")
  expect_true(inherits(pdd, "python.builtin.object"))
})

test_that("live seatable_list_selected looks rows up by a numeric id column", {
  con <- flytable_test_con_or_skip()

  sel <- try(seatable_list_selected(ids = 1:3, table = "testfruit",
                                    idfield = "nid", base = "test", con = con),
             silent = TRUE)
  skip_if(inherits(sel, "try-error") || is.null(sel),
          "testfruit list_selected failed (service issue)")
  expect_s3_class(sel, "data.frame")
  skip_if(nrow(sel) == 0, "no testfruit rows with nid in 1:3")
  expect_true(all(sel$nid %in% 1:3))
  expect_true(all(c("fruit_name", "person", "nid") %in% names(sel)))
})

test_that("live append + delete round-trip on testfruit", {
  con <- flytable_test_con_or_skip()

  # A random nid and a distinctive person keep this row clear of the rows other
  # CI jobs (and people) are editing at the same time.
  nid <- sample.int(1e7, 1)
  who <- "seatabler delete round-trip"
  findsql <- sprintf(
    "select `_id`, person, nid from testfruit where person='%s' AND nid=%d",
    who, nid)

  appended <- try(seatable_append_rows(
    data.frame(fruit_name = "kiwi", person = who, nid = nid),
    table = "testfruit", base = "test", con = con), silent = TRUE)
  skip_if(inherits(appended, "try-error"), "append failed (service issue)")
  # Safety net: if an assertion below fails before the delete, still clean up.
  on.exit({
    leftover <- try(seatable_query(findsql, base = "test", con = con,
                                   progress = FALSE), silent = TRUE)
    if (!inherits(leftover, "try-error") && isTRUE(nrow(leftover) > 0))
      try(seatable_delete_rows(leftover[["_id"]], table = "testfruit",
                               base = "test", con = con, DryRun = FALSE),
          silent = TRUE)
  }, add = TRUE)
  expect_true(appended)

  iddf <- try(seatable_query(findsql, base = "test", con = con, progress = FALSE),
              silent = TRUE)
  skip_if(inherits(iddf, "try-error") || is.null(iddf),
          "could not read back the appended row (service issue)")
  expect_equal(nrow(iddf), 1L)

  # Dry run returns the id without deleting; the real delete reports one row.
  expect_identical(seatable_delete_rows(iddf[["_id"]], table = "testfruit",
                                        base = "test", con = con), iddf[["_id"]])
  n <- seatable_delete_rows(iddf[["_id"]], table = "testfruit", base = "test",
                            con = con, DryRun = FALSE)
  expect_equal(unname(n), 1L)

  gone <- try(seatable_query(findsql, base = "test", con = con, progress = FALSE),
              silent = TRUE)
  skip_if(inherits(gone, "try-error"), "post-delete read failed (service issue)")
  expect_equal(nrow(gone), 0L)
})
