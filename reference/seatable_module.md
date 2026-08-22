# Import the seatable_api Python module

Imports the `seatable_api` Python module, on which every other seatabler
function relies. The result is cached for the session.

## Usage

``` r
seatable_module()
```

## Value

The imported `seatable_api` module.

## Details

seatabler depends on nat.python for Python environment management, so
`seatable_module()` is a thin wrapper over
[`nat.python::check_module()`](https://rdrr.io/pkg/nat.python/man/check_module.html).
That checks whether each module is installed (from distribution
metadata, without importing), imports it, and on absence either offers
to install it — interactively, via
[`nat.python::simple_python()`](https://rdrr.io/pkg/nat.python/man/simple_python.html)
into the managed natverse Python environment — or errors with guidance.
Both `seatable_api` and `pandas` are ensured: seatabler moves pandas
`DataFrame`s around directly and converts them with
[`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html),
but `seatable_api` does not itself depend on pandas, so a
`seatable_api`-only install would fail at the first pandas import. To
set Python up in one step beforehand, run
`nat.python::simple_python("minimal", pkgs = "seatable_api")` — the
`"minimal"` bundle installs pandas and `pkgs` adds `seatable_api` — or
`nat.python::simple_python("basic")` if you also want the wider natverse
Python stack.
