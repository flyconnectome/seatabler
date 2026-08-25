# base.R workspace resolution. The live discovery (get_base, get_metadata) is
# exercised by the flytable live tests; here we cover the pure resolution logic
# and the workspace-scan error paths with a mocked seatable_workspaces().

test_that("seatable_workspace_id returns a connection's own workspace_id", {
  con <- seatable_connection(url = "https://example.com/", workspace_id = 42,
                             token_envvar = "NO_TOKEN")
  # no server lookup needed when the connection already carries the id
  expect_identical(seatable_workspace_id("anybase", con = con), "42")
})

test_that("seatable_workspace_id scans workspaces and reports ambiguity", {
  con <- seatable_connection(url = "https://example.com/", token_envvar = "NO_TOKEN")
  wsdf <- data.frame(name = c("A", "B", "B"), workspace_id = c(1, 2, 3),
                     stringsAsFactors = FALSE)
  testthat::with_mocked_bindings(
    seatable_workspaces = function(...) wsdf,
    {
      expect_identical(seatable_workspace_id("A", con = con), "1")
      # base "B" lives in two workspaces -> ambiguous
      expect_error(seatable_workspace_id("B", con = con), "Multiple workspaces")
      # unknown base -> not found
      expect_error(seatable_workspace_id("Z", con = con), "Unable to find")
    })
})
