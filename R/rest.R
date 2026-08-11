# Direct REST transport.
#
# Most of seatabler goes through the `seatable_api` Python SDK, but a few
# SeaTable capabilities have no SDK equivalent (big data archive/unarchive,
# snapshots, and anything newer than the SDK). Those live behind two REST
# endpoint families that authenticate differently:
#
#   * account endpoints (`api/v2.1/...`)  -> Bearer <account API token>
#   * base endpoints (`api-gateway/...`)  -> Bearer <base JWT, from base$jwt_token>
#
# The two helpers below cover both, so new endpoints can be wrapped in a few
# lines rather than each growing its own httr2 pipeline.

#' Call a SeaTable REST endpoint directly
#'
#' @description Low-level access to SeaTable's HTTP API, for endpoints the
#'   Python SDK does not expose. `seatable_rest()` talks to the *account* API
#'   (paths under `api/v2.1/`, authenticated with the connection's API token);
#'   `seatable_base_rest()` talks to a *base* through the API gateway (paths
#'   under `api-gateway/api/v2/dtables/<base-uuid>/`, authenticated with that
#'   base's JWT).
#'
#' @details These are the transport behind [seatable_archive_rows()],
#'   [seatable_unarchive_rows()] and [seatable_snapshots()], and are exported so
#'   that consumer packages can reach endpoints seatabler does not yet wrap
#'   without reimplementing authentication.
#'
#'   Two details are easy to get wrong and are handled here. Requests are forced
#'   onto HTTP/1.1 (curl's `CURL_HTTP_VERSION_1_1`, numeric value 2), because
#'   SeaTable's gateway can return HTTP/2 framing errors under load. And JSON
#'   bodies encode `NA` as `null` rather than the string `"NA"`, which SeaTable
#'   rejects in number columns.
#'
#'   Rate-limited (429) and server-error (5xx) responses are retried with
#'   exponential backoff; other error statuses raise an error carrying
#'   SeaTable's own `error_message` where it supplies one.
#'
#' @param path Endpoint path relative to the server root (`seatable_rest()`) or
#'   to `api-gateway/api/v2/dtables/<base-uuid>/` (`seatable_base_rest()`).
#' @param con A [seatable_connection].
#' @param method HTTP method. Defaults to `"GET"`, or `"POST"` when a `body` is
#'   supplied.
#' @param body A list encoded as the JSON request body, or `NULL`.
#' @param query A named list of URL query parameters, or `NULL`.
#' @param retries Number of times to retry a 429 or 5xx response.
#' @param parse Whether to parse the JSON response (default) or return the raw
#'   `httr2` response object.
#'
#' @return The parsed JSON response as an R list, or an `httr2_response` when
#'   `parse = FALSE`. Endpoints with an empty body return `NULL`.
#' @export
#' @examples
#' \dontrun{
#' con <- seatable_connection("https://cloud.seatable.io/", token_envvar = "MY_TOKEN")
#'
#' # An account endpoint: which bases can I see?
#' seatable_rest("api/v2.1/dtables/", con = con)
#'
#' # A base endpoint, authenticated with the base JWT
#' base <- seatable_base("my_base", con = con)
#' seatable_base_rest("metadata/", base = base, con = con)
#' }
seatable_rest <- function(path, con = default_connection(), method = NULL,
                          body = NULL, query = NULL, retries = 3L,
                          parse = TRUE) {
  con <- as_connection(con)
  seatable_http(url = paste0(con$url, sub("^/+", "", path)),
                token = seatable_token(con), method = method, body = body,
                query = query, retries = retries, parse = parse)
}

#' @rdname seatable_rest
#' @param base A `Base` object from [seatable_base()], or a base name.
#' @export
seatable_base_rest <- function(path, base, con = default_connection(),
                               method = NULL, body = NULL, query = NULL,
                               retries = 3L, parse = TRUE) {
  con <- as_connection(con)
  if (is.character(base) || is.null(base))
    base <- seatable_base(base_name = base, con = con)
  # The gateway wants the bare host, and the base's own JWT rather than the
  # account token; the JWT is minted when the Base object is created.
  server <- sub("/+$", "", sub("^https?://", "", base$server_url))
  url <- sprintf("https://%s/api-gateway/api/v2/dtables/%s/%s",
                 server, base$dtable_uuid, sub("^/+", "", path))
  seatable_http(url = url, token = base$jwt_token, method = method, body = body,
                query = query, retries = retries, parse = parse)
}

# Shared httr2 pipeline for both helpers above.
seatable_http <- function(url, token, method = NULL, body = NULL, query = NULL,
                          retries = 3L, parse = TRUE) {
  if (!requireNamespace("httr2", quietly = TRUE))
    stop("The 'httr2' package is required for SeaTable REST calls. ",
         "Install it with install.packages('httr2').")
  if (is.null(method)) method <- if (is.null(body)) "GET" else "POST"
  req <- httr2::request(url)
  req <- httr2::req_method(req, method)
  # curl's CURL_HTTP_VERSION_1_1 is 2: SeaTable's gateway can emit HTTP/2
  # framing errors, so pin the older protocol.
  req <- httr2::req_options(req, http_version = 2)
  req <- httr2::req_headers(req,
                            Authorization = paste("Bearer", token),
                            Accept = "application/json")
  if (!is.null(query)) req <- httr2::req_url_query(req, !!!query)
  # na = "null": SeaTable rejects the default "NA" string in number columns.
  if (!is.null(body)) req <- httr2::req_body_json(req, body, na = "null")
  req <- httr2::req_retry(req, max_tries = max(1L, as.integer(retries) + 1L),
                          is_transient = function(resp)
                            httr2::resp_status(resp) %in% c(429L, 500L, 502L,
                                                            503L, 504L))
  # Handle failures ourselves so the user sees SeaTable's message, not httr2's.
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)
  status <- httr2::resp_status(resp)
  if (status >= 400L) stop(seatable_http_error(resp, status), call. = FALSE)
  if (!parse) return(resp)
  if (length(httr2::resp_body_raw(resp)) == 0L) return(invisible(NULL))
  tryCatch(httr2::resp_body_json(resp),
           error = function(e) httr2::resp_body_string(resp))
}

# Build an informative message from a failed response, preferring SeaTable's own
# error_message field over the raw body.
seatable_http_error <- function(resp, status) {
  msg <- tryCatch({
    if (grepl("json", httr2::resp_content_type(resp), fixed = TRUE)) {
      content <- httr2::resp_body_json(resp)
      content$error_message %||% content$error_msg %||% content$detail %||%
        httr2::resp_body_string(resp)
    } else {
      # A wrong URL gets SeaTable's HTML error page rather than JSON, and
      # pasting a whole web page into the console buries the actual problem.
      abbreviate_body(httr2::resp_body_string(resp))
    }
  }, error = function(e) "<could not parse the response body>")
  extra <- if (status == 429L)
    "\nThis is a rate limit; check your quota on the SeaTable server."
  else if (status == 404L)
    "\nCheck the endpoint path; a mistyped path returns the server's 404 page."
  else ""
  paste0("SeaTable REST request failed (HTTP ", status, "): ", msg, extra)
}

# Reduce a response body to something readable: strip HTML markup if that is
# what we got, collapse whitespace, and keep only the first few hundred
# characters.
abbreviate_body <- function(txt, max_chars = 300L) {
  if (!length(txt) || !nzchar(txt)) return("<empty response body>")
  if (grepl("<html", txt, ignore.case = TRUE)) {
    title <- sub(".*<title[^>]*>(.*?)</title>.*", "\\1", txt, ignore.case = TRUE)
    txt <- if (nchar(title) < nchar(txt)) paste0("<HTML page: ", trimws(title), ">")
           else "<HTML error page>"
  }
  txt <- trimws(gsub("\\s+", " ", txt))
  if (nchar(txt) > max_chars)
    txt <- paste0(substr(txt, 1L, max_chars), "... [truncated]")
  txt
}

`%||%` <- function(x, y) if (is.null(x)) y else x
