# seatabler — plan

A generic R client for [SeaTable](https://seatable.io) servers, factored
out of the seatable code currently embedded in `fafbseg` (and
independently in `bancr`). `seatabler` provides the server-agnostic core
— connect, query, read, write, cache — with **no default server and no
domain logic**. Consumer packages (`fafbseg`, `bancr`, `crantr`,
`aedes`) supply their own server configuration and keep their
flywire/CAVE/neuroglancer domain functions.

This document is self-contained: it captures the design, the function
inventory, the backward-compatibility constraints, and the phased plan,
so work can resume in a fresh session without prior context.

------------------------------------------------------------------------

## 1. Motivation

Two things drive this:

1.  **A clean multi-server configuration story.** The existing seatable
    code was written around a single Cambridge server, with the URL held
    in a global option (`fafbseg.flytable.url`) and the token in a fixed
    environment variable (`FLYTABLE_TOKEN`). Supporting additional
    servers has so far meant either temporarily mutating that global
    option (as `crantr::crant_meta()` does for `cloud.seatable.io`) or
    passing `url`/`token`/`workspace_id` to every function (as `bancr`
    does). Neither is clean. A first-class **connection object** solves
    this properly and is the central deliverable here.

2.  **Consolidation.** Generic seatable functionality currently exists
    in two places — `fafbseg` and `bancr` — with some overlap. `bancr`
    also implements useful capabilities that `fafbseg` lacks (see §5). A
    shared package lets all consumers converge on one implementation and
    share improvements.

The connection abstraction is the prize; the code consolidation follows
from it.

------------------------------------------------------------------------

## 2. Architecture

            ┌──────────────────────────────────────────────┐
            │  seatabler  (generic, no default server)      │
            │                                                │
            │  seatable_connection(url, token_envvar,        │
            │                      workspace_id, cachedir)   │
            │  default_connection() / with_connection()      │
            │                                                │
            │  seatable_login / _base / _query / _columns     │
            │  seatable_list_rows / _update_rows / _append…   │
            │  seatable_cached_table (+ delta sync)           │
            │  multi-select + coltype helpers                 │
            └───────────────┬────────────────────────────────┘
                            │ (each consumer binds ONE connection)
          ┌─────────────────┼───────────────────┬──────────────┐
          ▼                 ▼                   ▼              ▼
       fafbseg           bancr               crantr         aedes
      flytable_* +     banctable_* +       crant_meta,    aedes_* meta
      cam_meta,        franken_meta,       CAVE/mesh via  via fafbseg
      cell_types,      ngl_update,         fafbseg        wrappers
      meta (domain)    status (domain)

Consumers depend on `seatabler` (directly or transitively via `fafbseg`)
and keep all flywire/CAVE/materialisation/neuroglancer logic. Nothing
domain- specific moves into `seatabler`.

------------------------------------------------------------------------

## 3. The connection model (central design decision)

**Chosen approach: a connection object with a resolvable default, bound
at the wrapper layer.** This combines the strengths of all three
candidate designs (explicit object / package options+envvar /
per-function args) while avoiding each one’s drawback.

- **`seatable_connection(url, token_envvar, workspace_id, cachedir, name)`**
  is the unit of configuration. It stores the token
  *environment-variable name*, not the token value, so connections are
  safe to print, share and inspect. The token is resolved lazily at call
  time via `seatable_token(con)`.
- **Generic functions take `con = default_connection()`.**
  [`default_connection()`](https://flyconnectome.github.io/seatabler/reference/default_connection.md)
  returns the registered “current” connection, or builds one from
  `seatabler.url` / `seatabler.token_envvar` / `seatabler.workspace_id`
  options, or errors with guidance if no URL is available. So
  interactive users can set a default once and never pass `con`.
- **Wrapper packages bind the connection, so end users never see the
  triple.** `fafbseg::flytable_query()` supplies the Cambridge
  connection internally; `crant_meta()` supplies a crantr connection;
  `banctable_query()` supplies bancr’s. Multiple servers are simply
  multiple connection objects — no global mutation, no per-call argument
  sprawl.

This directly resolves both existing pain points: crantr’s “mutate a
global option mid-call” becomes “bind a crantr connection”, and bancr’s
“pass url/token/workspace everywhere” becomes “one connection instance”.

**Locking this contract (the connection constructor + how the default is
resolved) is the one thing that must be agreed before wider surgery**,
because it touches every function signature. Everything else is cheap
and independent.

Sketch (see `R/connection.R` for the initial implementation):

``` r

con <- seatable_connection(
  url          = "https://flytable.mrc-lmb.cam.ac.uk/",
  token_envvar = "FLYTABLE_TOKEN",
  workspace_id = NULL)             # discovered from base name if NULL

df <- seatable_query("SELECT * FROM info", con = con)

# or set a session default and drop the argument
set_default_connection(con)
df <- seatable_query("SELECT * FROM info")
```

Consumer bindings (the pattern to show Alex — real, minimal wrappers):

``` r

# fafbseg
.flytable_con <- function() seatable_connection(
  url = getOption("fafbseg.flytable.url", "https://flytable.mrc-lmb.cam.ac.uk/"),
  token_envvar = "FLYTABLE_TOKEN")
flytable_query <- function(sql, ...) seatabler::seatable_query(sql, con = .flytable_con(), ...)

# bancr
.banctable_con <- function() seatable_connection(
  url = "https://cloud.seatable.io/", token_envvar = "BANCTABLE_TOKEN",
  workspace_id = "57832")
banctable_query <- function(sql, ...) seatabler::seatable_query(sql, con = .banctable_con(), ...)

# crantr (replaces the withr::local_options URL-mutation hack)
.crant_con <- function() seatable_connection(
  url = "https://cloud.seatable.io/", token_envvar = "CRANTTABLE_TOKEN")
```

------------------------------------------------------------------------

## 4. Function inventory (three buckets)

### Bucket A — generic core → lives in `seatabler` (ported from fafbseg)

`login`, `set_token`, `check_seatable`, `base` (+ workspace/table
resolution), `query` (with pagination), `list_rows`, `columns`, `nrow`,
`update_rows`, `append_rows`, `delete_rows`, `select_options`,
`add_select_options`, `cached_table` (+ `full_fetch` / `delta_sync` /
`sync_metadata`), and the schema/coercion helpers (`fix_coltypes`,
`parse_date`, the multi-select resolve/check/listify functions,
`col_types`, `sql2fields`, `pandas2df`, `null2na`). A generic
`seatable_list_selected(ids, idfield, …)` with **no** ID coercion.

### Bucket B — thin wrappers → stay in `fafbseg` (names preserved forever, see §6)

`flytable_*` versions of every Bucket-A function: same names, Cambridge
connection bound, bodies delegate to `seatabler::seatable_*`.

### Bucket C — domain logic → stays in the consumer package

- **fafbseg:** `cam_meta`, `flytable_cell_types`, `flytable_meta`,
  `flytable_set_celltype`, `add_celltype_info`, the
  `flytable_list_selected` wrapper (it calls `flywire_ids()` before the
  generic list-selected), and all `flytable-wip.R` functions.
  `simple_python` (python-env management) stays here too; `seatabler`
  ships only a minimal `check_seatable()` (see §5a for how it reuses
  `simple_python` without depending on fafbseg).
- **bancr:** `banctable_ngl_update`, `banc_update_status`,
  `banctable_updateids`, `banctable_annotate`, `franken_meta`.

------------------------------------------------------------------------

## 5. Capabilities in bancr that fafbseg does not have

`bancr` independently implements a parallel seatable client and, in
doing so, adds generic capabilities that are **not present in fafbseg**.
These are genuine additions worth having in the shared package. They are
**reserved additive surface (owner: bancr)** — not required for the
first `seatabler` release, and best contributed by bancr when it
migrates:

> **Status (2026-08-11, ASB).** Items 1–7 below have now been
> contributed from bancr, in `R/rest.R`, `R/schema.R`, `R/bigdata.R`,
> `R/snapshots.R` and `R/query.R`; item 5 was already present in
> `R/columns.R`. They are additive — nothing in Phases 1–4 depends on
> them. (The former `TODO(port)` coercion markers have since been
> resolved by delegating to
> [`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html).)
> Two deliberate departures from the sketch below: the REST helper uses
> `httr2` rather than `httr`, since bancr’s api-gateway code was already
> written against it; and only snapshot *listing* is wrapped, because
> restoring is destructive and better done in the UI, which confirms
> first.

1.  **Column-schema mutation** — add / batch-add / delete columns (SDK
    `base.insert_column` / `delete_column`, with `ColumnTypes` enum
    handling and the `convert = FALSE` reticulate detail that avoids the
    enum being coerced back to a string).
2.  **Big-data archive / unarchive** — move rows to/from SeaTable “big
    data” storage (REST
    `api-gateway/api/v2/dtables/.../archive-view|unarchive`).
3.  **Snapshots** — list/create table snapshots (REST
    `api/v2.1/workspace/…`).
4.  **A REST/JWT transport** — (2) and (3) authenticate with
    `base$jwt_token` as a Bearer token against the api-gateway, a
    transport the SDK-only code does not use. `seatabler` should provide
    a small REST helper (base uuid + jwt + `httr`) so these functions
    are additive rather than requiring core changes. This ~30-line
    helper is worth building up front even though the first-party
    consumers are SDK-only, precisely so a future bancr migration needs
    minimal changes to `seatabler` itself.
5.  **Column `key` exposure** — `columns(..., include_key = TRUE)`
    returns the internal column key (needed for `delete_column` and for
    debugging API errors that reference keys like `"8blF"`).
6.  **Rate-limit (429) handling + retry/backoff** in the query path — a
    robustness improvement to fold into `seatable_query`.
7.  **Read-side coercion of numpy/py-object columns** — extra guards for
    columns that come back as numpy arrays / Python objects.
    *Delivered:* now handled by
    [`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html)
    (see §5a), which replaced seatabler’s minimal in-package converter.

**Multi-select note:** both fafbseg and bancr handle multi-select
columns. fafbseg’s implementation is the more complete one (it validates
values against existing select-options, supports `allow_new_options`,
and already has a JSON-payload path). `seatabler` should adopt
**fafbseg’s** multi-select implementation as canonical; a future bancr
migration can retire its own variant.

------------------------------------------------------------------------

## 5a. Python provisioning via nat.python (not fafbseg)

seatabler depends on **`nat.python`** (`flyconnectome/nat.python`;
`Imports` + `Remotes`) for *both* Python concerns:

- **pandas → R conversion + module introspection.**
  [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
  hands the pandas `DataFrame` to
  [`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html),
  which recovers 64-bit ids as `bit64`, flattens object/numpy columns
  and coerces datetimes — the read-side coercion this plan once listed
  as a seatabler TODO (§5, item 7).
- **Environment provisioning.** nat.python owns the *environment engine*
  — the mechanics extracted from fafbseg’s `simple_python()` (managed
  miniconda, reticulate env selection, package install) minus fafbseg’s
  opinionated package bundles. seatabler ensures `seatable_api` is
  present by calling that engine directly.

**Why nat.python is an acceptable dependency where fafbseg was not.**
The original concern was that fafbseg manages the shared Python
environment via `simple_python()`, yet seatabler must not depend on
fafbseg — for two independent reasons: fafbseg is heavy, and **fafbseg
depends on seatabler**, so `seatabler → fafbseg` would be a dependency
cycle. nat.python has neither problem: it is a lightweight, cycle-free
utility (core deps ~`reticulate` + `bit64`). So seatabler simply depends
on it for provisioning and conversion alike.

**This retires the inversion-of-control hook.** Earlier drafts avoided
the fafbseg dependency with a `seatabler.python_provisioner` option that
fafbseg registered `simple_python` into. With nat.python as a direct
dependency that dance is unnecessary: seatabler calls nat.python’s env
engine to install `seatable_api`, and fafbseg users, standalone users
and CI share one code path.

**Status / sequencing — DONE (2026-08-21).** Both concerns now route
through nat.python directly; the inversion-of-control hook has been
removed entirely.
[`seatable_module()`](https://flyconnectome.github.io/seatabler/reference/seatable_module.md)
(`R/auth.R`) calls
[`nat.python::check_module()`](https://rdrr.io/pkg/nat.python/man/check_module.html)
for both `pandas` and `seatable_api` — no `seatabler.python_provisioner`
option, no interim
[`reticulate::py_install`](https://rstudio.github.io/reticulate/reference/py_install.html)
step. Provisioning in one shot is
`nat.python::simple_python("minimal", pkgs = "seatable_api")` (the
`"minimal"` bundle installs pandas — nat.python’s own baseline — and
`pkgs` adds `seatable_api`). CI provisions through exactly this path
(see `.github/workflows/R-CMD-check.yaml`), so fafbseg users, standalone
users and CI share one code path.

## 6. Backward compatibility (hard constraint)

There are on the order of a few hundred direct calls to the generic
`flytable_*` functions in analysis code outside the packages (scripts,
notebooks). The most-used generics are `flytable_query`,
`flytable_update_rows`, `flytable_list_rows`, `flytable_list_selected`,
`flytable_append_rows`, `flytable_delete_rows`. (The heavily-used
`flytable_set_celltype`, `flytable_meta`, `flytable_cell_types` are
domain functions that stay in fafbseg regardless.)

**Policy: the `fafbseg::flytable_*` generic names are permanent thin
wrappers, not deprecated.** They keep their current signatures and
Cambridge defaults forever, delegating to `seatabler`. No deprecation
cycle. This is cheap (wrappers cost nothing) and protects existing
analysis code.

**Acceptance gate for the fafbseg re-point:** `aedes` must pass its
checks with **zero code changes**. `aedes` only calls
`fafbseg::flytable_*`, so if the wrappers preserve signatures/defaults,
aedes needs no edits — aedes needing changes is the signal the compat
layer is wrong. Concretely, snapshot
[`formals()`](https://rdrr.io/r/base/formals.html) of the six wild-used
generics before and after the change and diff them.

------------------------------------------------------------------------

## 7. Cache backend

`flytable_cached_table()` currently relies on a shared `cachem`-based
disk-cache factory (`ln()` / `flywire_leaves_cache()` in
`fafbseg/R/flywire-api.R`), which also backs flywire-leaves and l2
caches. It is generic (a `cache_disk` + optional layered `cache_mem`)
but lives in fafbseg.

**Decision:** duplicate the ~15-line factory in `seatabler` for now
(keyed on a `seatabler.cachedir` option). Extracting it to a small
shared cache package can come later if a second consumer makes
duplication painful. It should **not** go into `nat.utils`, which is
intentionally near-zero-dependency and would not want a `cachem`
dependency.

------------------------------------------------------------------------

## 8. Phased plan (with ownership)

- **Phase 0 — connection contract (design). ✅ DONE.**
  [`seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md)
  and default-resolution implemented and in use.
- **Phase 1 — seatabler core. ✅ DONE.** Bucket A ported from fafbseg
  (no bancr extras): connection/auth, `seatable_query` (paginated),
  `seatable_columns` (+ add/delete/select-options), the read generics
  `seatable_list_rows` / `seatable_list_selected`, the row writes
  `seatable_update_rows` / `seatable_append_rows` /
  `seatable_delete_rows`, big-data archive/unarchive, snapshots, and the
  REST/JWT transport. Read-side coercion is delegated to
  [`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html).
  Live tests pass in CI (SKIP 0).
- **Phase 2 — re-point fafbseg. ⏳ NEXT.** `flytable_*` generics become
  thin wrappers (§6). Domain functions stay and call `seatabler`
  internally. Acceptance gate: aedes unchanged (snapshot
  [`formals()`](https://rdrr.io/r/base/formals.html) of the six generics
  before/after).
- **Phase 3 — aedes.** Expected zero code changes; optionally give aedes
  its own clean connection for `aedes_main`.
- **Phase 4 — crantr.** Replace the `crant_meta()` global-option hack
  with a crantr connection (`CRANTTABLE_TOKEN`, `cloud.seatable.io`).
  crantr still depends on fafbseg for `cam_meta`/CAVE/meshes; only its
  seatable config changes.
- **Phase 5 — bancr (owner: Alex, later).** `banctable_*` become
  wrappers over `seatabler`; the Bucket-B capabilities (§5) are
  contributed additively. Not a prerequisite for anything above.

Consumers not owned here (`bancr`) can migrate on their own schedule;
nothing in Phases 1–4 depends on them.

------------------------------------------------------------------------

## 9. Making a future bancr migration cheap

To let bancr migrate with minimal changes to `seatabler` itself:

1.  The connection object already carries
    `url + token_envvar + workspace_id` — bancr’s config is just an
    instance.
2.  Give stable (even if internal) homes to the helpers bancr currently
    reaches for: `check_seatable`, base/workspace resolution,
    `fix_coltypes`, `pandas2df`, `null2na`, `sql2fields`, the
    multi-select payload builders.
3.  Ship the small REST/JWT transport helper (§5.4) up front.
4.  Leave column-schema / big-data / snapshots as documented additive
    surface.

------------------------------------------------------------------------

## 10. Open questions

1.  **Hosting:** `flyconnectome/seatabler` (where the consumer packages
    live) or `natverse/seatabler`. Leaning flyconnectome.
2.  **CRAN:** submit eventually? Affects dependency hygiene.
3.  **Python dependency:** resolved (see §5a) — `seatabler` depends on
    `nat.python` and calls its env engine (`check_module` /
    `simple_python`) directly for both provisioning and pandas→R
    conversion. The `seatabler.python_provisioner` hook has been
    removed; there is no consumer registration step. nat.python’s
    `simple_python` “basic” bundle already installs `seatable_api`, and
    the “minimal” bundle installs pandas.
4.  **Cache location default per server** (`seatabler.cachedir` +
    per-connection `cachedir`).
5.  **Ownership/authorship** of the package (currently scaffolded solo;
    add co-authors as agreed).

------------------------------------------------------------------------

## 11. Status of this skeleton

No longer a skeleton — Phase 1 is complete and the suite passes against
a live server in CI (89 tests, SKIP 0). Core files:

- `R/connection.R` —
  [`seatable_connection()`](https://flyconnectome.github.io/seatabler/reference/seatable_connection.md),
  [`default_connection()`](https://flyconnectome.github.io/seatabler/reference/default_connection.md),
  [`set_default_connection()`](https://flyconnectome.github.io/seatabler/reference/set_default_connection.md),
  [`with_connection()`](https://flyconnectome.github.io/seatabler/reference/with_connection.md),
  [`seatable_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_token.md),
  print method.
- `R/auth.R` —
  [`seatable_module()`](https://flyconnectome.github.io/seatabler/reference/seatable_module.md),
  [`seatable_login()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md),
  [`seatable_generate_token()`](https://flyconnectome.github.io/seatabler/reference/seatable_login.md).
- `R/base.R` —
  [`seatable_base()`](https://flyconnectome.github.io/seatabler/reference/seatable_base.md) +
  workspace/table resolution.
- `R/columns.R` —
  [`seatable_columns()`](https://flyconnectome.github.io/seatabler/reference/seatable_columns.md) +
  column-schema mutation and select-options.
- `R/query.R` —
  [`seatable_query()`](https://flyconnectome.github.io/seatabler/reference/seatable_query.md)
  with pagination.
- `R/rest.R`, `R/schema.R`, `R/bigdata.R`, `R/snapshots.R` — REST/JWT
  transport, schema helpers, big-data archive/unarchive, snapshot
  listing (the bancr-origin additive surface from §5).
- `tests/testthat/` — connection-object unit tests plus live tests
  (`test-flytable-live.R`) that skip gracefully without a token.

The former `TODO(port)` items are done: read-side coercion
(`fix_coltypes`, full `pandas2df`, multi-select) is delegated to
[`nat.python::pandas2df()`](https://rdrr.io/pkg/nat.python/man/pandas2df.html)
rather than reimplemented here.
