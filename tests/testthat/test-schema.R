test_that("seatable_add_columns requires name and type columns", {
  expect_error(seatable_add_columns("t", data.frame(name = "a")), "`name` and `type`")
})

test_that("seatable_column_type resolves names and rejects unknown ones", {
  skip_if_not(seatable_api_available())
  enum <- seatabler:::seatable_column_type("text")
  expect_s3_class(enum, "python.builtin.object")
  # Already an enum member: passed through untouched.
  expect_identical(seatabler:::seatable_column_type(enum), enum)
  expect_error(seatabler:::seatable_column_type("no-such-type"), "Unknown SeaTable")
})
