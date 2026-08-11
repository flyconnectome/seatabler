# seatabler <img src="man/figures/logo.png" align="right" height="139" alt="seatabler hex logo" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/flyconnectome/seatabler/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/flyconnectome/seatabler/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

> **⚠️ Design-phase package.** seatabler is under active design and is **not yet
> ready for use**. The API is unstable and may change without notice. See
> [`seatabler-plan.md`](seatabler-plan.md) for the full design, scope and
> rationale.

seatabler is a server-agnostic R client for [SeaTable](https://seatable.io)
databases. A `seatable_connection` captures a server URL, the environment
variable (or an embedded literal value) holding your API token, and an optional
workspace; generic `seatable_*` functions then query, read, write and cache
tables against any server.

There is deliberately **no default server and no domain-specific logic**:
packages such as [fafbseg](https://github.com/natverse/fafbseg) and
[bancr](https://github.com/flyconnectome/bancr) are expected to wrap seatabler
with their own server configuration so that their users need no setup.

## Status

This repository currently contains the connection model and a query vertical
slice ported from fafbseg. Substantial work remains — see
[`seatabler-plan.md`](seatabler-plan.md). Expect breaking changes.

## Installation

```r
# install.packages("remotes")
remotes::install_github("flyconnectome/seatabler")
```

seatabler talks to SeaTable through the official `seatable_api` Python package
via [reticulate](https://rstudio.github.io/reticulate/). It does **not** manage
Python environments itself: on first use it will offer to install `seatable_api`,
or a wrapper package can provision it into the environment it manages (see
`?seatable_module`).

## Usage

```r
library(seatabler)

con <- seatable_connection(
  url = "https://cloud.seatable.io/",
  token_envvar = "SEATABLE_TOKEN")

# One-off: mint an API token from your credentials and store it in ~/.Renviron
seatable_generate_token("me@example.com", "secret", con = con)

seatable_query("SELECT * FROM my_table", con = con)
```

Tokens are per-server, so give each server its own `token_envvar` name (wrapper
packages typically pin one). Connections never print the token value.

## License

GPL-3
