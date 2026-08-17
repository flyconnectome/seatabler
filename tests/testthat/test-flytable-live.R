# Live test against the public-ish `testfruit` table on the LMB flytable server,
# borrowed from fafbseg's test-flytable.R. It needs the seatable_api Python
# package and a FLYTABLE_TOKEN (a repository secret in CI); it skips gracefully
# when either is missing, so it is a no-op on a machine without Python or a token.

flytable_test_connection <- function() {
  seatable_connection(url = "https://flytable.mrc-lmb.cam.ac.uk/",
                      token_envvar = "FLYTABLE_TOKEN",
                      workspace_id = "5", name = "flytable-test")
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
