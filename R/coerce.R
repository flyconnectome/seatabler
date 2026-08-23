# Schema-aware coercion of SeaTable results after nat.python::pandas2df().
#
# pandas2df() flattens object columns whose cells are all scalar, but leaves
# array-valued cells -- i.e. SeaTable multiple-select columns -- as R
# list-columns, and does not apply SeaTable's per-column types. That schema-aware
# step lived in fafbseg and was dropped when flytable_query became
# seatable_query. These are ports of fafbseg's flytable2df / flytable_fix_coltypes
# / flytable_parse_date, carried over as-is because the behaviour (multi-select
# NaN shapes, date formats, batch artefacts) is subtle and proven against live
# tables. Adaptations from the originals are limited and flagged inline:
#   * the `is.character(tidf)` self-lookup branch is dropped -- callers always
#     pass a resolved schema frame from seatable_columns();
#   * fafbseg's warn_hourly() nag is replaced by a silent base-R fallback.
# seatable_columns() carries the per-column `data` metadata (formats, options),
# so st_fix_coltypes() parses dates with each column's declared format; the
# NULL-tidf$data guard below only matters for callers passing a schema without
# it, where st_parse_date() falls back to format guessing.

#' @noRd
st_coerce_df <- function(df, tidf = NULL, collapse = TRUE) {
  if(!isTRUE(ncol(df)>0))
    return(df)
  nr=nrow(df)
  mscols=if(!is.null(tidf)) tidf$name[tidf$type=='multiple-select'] else character(0)
  listcols=sapply(df, is.list)
  for(i in which(listcols)) {
    # a genuinely unset multi-select cell can arrive in different shapes
    # depending on chunk boundaries: character(0)/NULL from the
    # seatable/pandas conversion, or a scalar NA/NaN -- pandas fills a
    # column with float NaN when, for a given fetch, at least one but not
    # all rows lack the underlying key, which depends on which rows happen
    # to be batched together, not on the actual cell content. For
    # multi-select columns specifically, treat a scalar NA/NaN cell as
    # empty too, rather than as a literal option named "NaN"
    isna=if(colnames(df)[i] %in% mscols)
      vapply(df[[i]], function(v) length(v)==1 && is.na(v), logical(1))
    else rep(FALSE, length(df[[i]]))
    li=lengths(df[[i]])
    li[isna]=0L
    if(isTRUE(all(li==1))) {
      ul=unlist(df[[i]])
      if(!isTRUE(length(ul)==nr))
        warning("List column :", colnames(df)[i], " cannot be vectorised!")
      else df[[i]]=ul
    } else if(isTRUE(all(li %in% 0:1))) {
      # nzchar() on the list column itself doesn't do what's intended here
      # (it's always TRUE, since it stringifies each list element rather
      # than looking inside it) -- convert length-0/empty-string cells to
      # NA explicitly instead, one cell at a time (using the li computed
      # above, which already folds in the NA/NaN handling)
      df[[i]]=vapply(seq_along(df[[i]]), function(j) {
        v=df[[i]][[j]]
        if(li[j]==0 || !nzchar(v)) NA_character_ else as.character(v)
      }, character(1))
    } else if(!isFALSE(collapse)){
      if(isTRUE(collapse)) collapse=','
      collapsed=sapply(df[[i]], paste0, collapse=collapse)
      # paste0(character(0), collapse=...) gives "" not NA, which would
      # make an empty cell read back differently (NA vs "") purely because
      # some other row in the same batch happens to have multiple values --
      # keep empty cells as NA regardless, consistent with the two branches
      # above
      collapsed[li==0]=NA
      df[[i]]=collapsed
    } else
        warning("List column :", colnames(df)[i], " cannot be vectorised!")
  }
  if(is.null(tidf)) df else st_fix_coltypes(df, tidf=tidf)
}

#' @noRd
st_fix_coltypes <- function(df, tidf, tz='UTC') {
  coltypes=sapply(df, mode)
  for(col in colnames(df)) {
    sttype=tidf$type[match(col, tidf$name)]
    newtype=tidf$rtype[match(col, tidf$name)]
    curtype=coltypes[col]
    if(isTRUE(curtype==newtype) || coltypes[col]=="list") next
    if(col %in% c("_mtime", "_ctime") || isTRUE(sttype=='mtime')) {
      # one of the automatic timestamp columns
      df[[col]]=st_parse_date(df[[col]], format = 'timestamp', tz=tz)
    } else {
      if(is.na(newtype)) next
      if(newtype=='POSIXct') {
        # use the column's declared date format from seatable_columns()'s
        # `data` metadata; st_parse_date() guesses when it is absent
        coldata=if(!is.null(tidf$data)) tidf$data[[match(col, tidf$name)]] else NULL
        df[[col]]=st_parse_date(df[[col]], colinfo = coldata, tz=tz)
      } else {
        newcol=try(methods::as(df[[col]], newtype), silent = T)
        if(inherits(newcol, 'try-error'))
          warning("Unable to change column: ", col, " to type: ", newtype)
        else df[[col]]=newcol
      }
    }
  }
  df
}

#' @noRd
st_parse_date <- function(x, colinfo=NULL,
                          format=c("guess", 'ymd', 'ymdhm', 'timestamp'),
                          tz='UTC', lubridate=NA) {
  formats=c(ymdhm="%Y-%m-%d %H:%M",
            ymdhms="%Y-%m-%d %H:%M:%S",
            ymd="%Y-%m-%d",
            timestamp="%Y-%m-%dT%H:%M:%OS%z")
  format=match.arg(format)
  format <- if(format!="guess") format
  else  if(!is.null(colinfo$format)) {
    if(colinfo$format=="YYYY-MM-DD HH:mm")
      "ymdhm"
    else if(colinfo$format=="YYYY-MM-DD")
      "ymd"
    else {
      warning("Unrecognised date format:", colinfo$format)
      NA
    }
  } else {
    # inspect
    if(any(grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", x, perl=T))) {
      if(any(grepl("Z", x, fixed = T))) "ymdhms"
      else if(any(grepl("T", x, fixed = T))) "timestamp"
      else if(any(grepl("[0-2][0-9]:[0-5][0-9]", x, perl = T))) "ymdhm"
      else "ymd"
    } else {
      if(all(is.na(x)|!nzchar(x))) {
        warning("cannot parse empty date column")
      }
      else {
        warning("Unrecognised date format")
      }
      NA
    }
  }
  if(is.na(format)) return(x)
  stopifnot(format %in% names(formats))

  if(format=='ymdhm') {
    # list_rows and SQL give different date formats for seatable date fields!
    # list_rows: "2021-06-23 07:01"
    # SQL: '2022-01-12T09:30:00Z' (GMT) '2021-08-05 08:30:00' (other)
    if(any(grepl("[0-2][0-9]:[0-5][0-9]:[0-6][0-9]", x, perl = T)))
      format="ymdhms"
  }
  if(format=='ymdhms') {
    # there is some strange bug in the python client for GMT datetimes
    # related to https://github.com/seatable/seatable-api-python/issues/53
    x=sub('Z', '', x, fixed = T)
    x=sub('T', ' ', x, fixed = T)
  }
  format_str=formats[format]

  if(is.na(lubridate))
    lubridate=requireNamespace('lubridate', quietly = TRUE)
  if(lubridate) {
    # lubridate is fussy about parsing and insists on character vectors
    x[is.na(x)]=NA_character_
    lubridate::fast_strptime(x, format_str, tz=tz, lt = FALSE)
  } else {
    # remove colon from timezone to keep base::strptime happy
    if(format=='timestamp')
      x=sub("([+\\-][0-2][0-9]):([0-5][0-9])$","\\1\\2",x, perl = T)
    strptime(x, format_str, tz=tz)
  }
}
