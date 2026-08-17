# Argument validation only: everything past it needs a live server.

test_that("seatable_archive_rows insists on exactly one view", {
  expect_error(seatable_archive_rows("t"), "exactly one")
  expect_error(seatable_archive_rows("t", view_name = "v", view_id = "1"),
               "exactly one")
})

test_that("seatable_unarchive_rows rejects an empty row_ids", {
  expect_error(seatable_unarchive_rows("t", row_ids = character()), "empty")
})
