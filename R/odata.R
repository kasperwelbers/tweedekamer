

#' Select entity
#'
#' See the [Information model](https://opendata.tweedekamer.nl/documentatie/informatiemodel) for valid entities.
#'
#' @param entity
#'
#' @return A tk_url object
#' @export
#'
#' @examples
tk_entity <- function(entity) {
  entity = tolower(entity)
  if (!entity %in% tk_entities()) {
    stop("Invalid entity. See tk_entities() for valid entities.")
  }
  url = sprintf("https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/%s", entity)
  structure(list(url=url, params=list()), class = "tk_url_builder")
}

build_url <- function(tk_url) {
  params = list(paramname = "value")

  if (length(tk_url$params) > 0) {
    params = unlist(tk_url$params)
    params = paste0(names(params), '=', params)
    url=paste0(tk_url$url, '?', paste(params, collapse='&'))
  } else {
    url=tk_url$url
  }
  URLencode(url)
}

rm_null_from_list <- function(l) {
  l[!sapply(l, function(x) {
    if (is.null(x)) return(T)
    if (length(x) == 0) return(T)
    return(F)
  })]
}

bind_all_rows <- function(rows) {
  nonempty_rows = lapply(rows, function(row) {
    for (rname in names(row)) {
      x = row[[rname]]
      if (length(x) == 0) row[[rname]] = NULL
      if (class(x) == 'list') {
        if (!is.null(names(x))) {
          row[[rname]] = NULL
          for (nested in names(x)) {
            row[[paste(rname, nested, sep='.')]] = x[[nested]]
          }
        }
      }
    }
    rm_null_from_list(row)
  })
  dplyr::bind_rows(nonempty_rows)
}



#' Count the number of results for a query
#'
#' @param tk_url A tk_url_builder object
#'
#' @return a number
#' @export
#'
#' @examples
tk_count <- function(tk_url) {
  tk_url$params[["top"]] = 1
  tk_url$params[['$count']] = 'true'
  tk_url$params[['$format']] = 'application/json;odata.metadata=none'

  res = build_url(tk_url) |>
    cached_get()
  res$`@odata.count`
}

#' Get list of results for query
#'
#' @param tk_url  A tk_url_builder object (the output of tk_entity)
#' @param limit   Number of results to return.
#' @param skip    Number of results to skip.
#' @param meta    Either 'none', 'minimal' or 'full'
#'
#' @return A tibble with the results
#' @export
#'
#' @examples
tk_list <- function(tk_url, limit=Inf, skip=NULL, meta='minimal', expand_notnull=TRUE) {
  if (limit <= 250) {
    tk_url$params[['$top']] = limit
  }
  if (!is.null(skip)) tk_url$params[['$skip']] = skip
  if (!meta %in% c('none','minimal','full')) stop("Invalid meta")
  tk_url$params[['$count']] = 'true'
  tk_url$params[['$format']] = sprintf('application/json;odata.metadata=%s', meta)

  first_page <- build_url(tk_url) |>
    cached_get()

  if (length(first_page$value) > limit) {
    d = bind_all_rows(first_page$value)
    return(head(d, limit))
  }

  test <<- first_page$value
  rows <- list()
  rows[['']] <- bind_all_rows(first_page$value)
  nextlink <- first_page$`@odata.nextLink`

  n  <- first_page$`@odata.count`
  pb <- progress::progress_bar$new(total = n)
  pb$tick(length(first_page$value))
  total = length(first_page$value)
  while (!is.null(nextlink)) {
    res = cached_get(nextlink)
    total = total + length(res$value)
    pb$tick(length(res$value))
    rows[['']] = bind_all_rows(res$value)

    if (total >= limit) break
    nextlink = res$`@odata.nextLink`
  }

  head(bind_all_rows(rows), limit)
}

cached_get <- function(url) {
  message(url)
  if (!dir.exists('tk_API_cache')) dir.create('tk_API_cache')
  cache_file = file.path('tk_API_cache', digest::digest(url))
  if (file.exists(cache_file)) {
    readRDS(cache_file)
  } else {
    res = httr2::request(url) |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    saveRDS(res, cache_file)
    res
  }
}


#` Select attributes
#'
#' @param tk_url  A tk_url_builder object (the output of tk_entity)
#' @param attrs  A character vector of attribute names
#'
#' @return
#' @export
tk_select <- function(tk_url, fields) {
  tk_url$params[['$select']] = paste(fields, collapse=',')
  tk_url
}

#' Add a filter
#'
#' @param tk_url  A tk_url_builder object (the output of tk_entity)
#' @param ...     Filters to apply. Use by_string, by_date, by_number, by_boolean, filter_and, filter_or
#'
#' @return
#' @export
#'
#' @examples
#' tk_entity('persoon') %>%
#'   tk_filter(by_string('geslacht', 'eq', 'vrouw')) %>%
#'   tk_count()
#'
#' tk_entity('persoon') %>%
#'   tk_filter(
#'     by_string('geslacht', 'eq', 'vrouw'),
#'     filter_or(
#'       by_date('geboortedatum', 'lt', '1970-01-01T23:00:00Z'),
#'       by_date('geboortedatum', 'gt', '1980-01-01')
#'     )
#'   ) %>%
#'   tk_count()
tk_filter <- function(tk_url, ...) {
  filter = paste(list(...), collapse=' and ')
  if (is.null(tk_url$params[['$filter']])) {
    tk_url$params[['$filter']] = filter
  } else {
    tk_url$params[['$filter']] = paste0('(',tk_url$params[['$filter']], ') and (', filter, ')')
  }
  tk_url
}



#' Filter on string value
#'
#' @param field     Field to filter on
#' @param operator  Operator to use. One of 'eq', 'contains', 'startswith', 'endswith'
#' @param value     string value
#'
#' @return
#' @export
by_string <- function(field, operator, value) {
  if (!operator %in% c('eq','contains','startswith','endswith')) stop("Invalid operator")
  if (operator == 'eq') {
    sprintf("%s %s '%s'", field, operator, value)
  } else {
    sprintf("%s(%s, '%s')", operator, field, value)
  }
}



#` Filter on not null (or null)
#'
#' @param field     Field to filter on
#' @param value     Either 'not_null' or 'null'
#'
#' @return
#' @export
by_exists <- function(field, value=c('not_null','null')) {
  value = match.arg(value)
  if (value == 'null') {
    sprintf("%s eq null", field)
  } else {
    sprintf("%s ne null", field)
  }
}

#` Filter on date value
#'
#' @param field     Field to filter on
#' @param operator  Operator to use. One of 'eq', 'lt', 'gt'
#' @param value     Date value as a string in the format 'YYYY-MM-DD' or 'YYYY-MM-DDTHH:MM:SSZ'
#'
#' @return
#' @export
by_date <- function(field, operator, value) {
  if (!grepl('T', value)) {
    if (!grepl('^(\\d{4}-\\d{2}-\\d{2})$', value)) stop("Invalid date format")
  } else {
    if (!grepl('^(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2})Z$', value)) stop("Invalid date format")
  }
  if (!operator %in% c('eq', 'lt', 'gt')) stop("Invalid operator")

  sprintf("%s %s %s",  field, operator, value)
}


#` Filter on number value
#'
#' @param field     Field to filter on
#' @param operator  Operator to use. One of 'eq', 'lt', 'gt'
#' @param value     Number
#'
#' @return
#' @export
by_number <- function(field, operator, value) {
  if (!is.numeric(value)) stop("Value must be numeric")
  if (!operator %in% c('eq', 'lt', 'gt')) stop("Invalid operator")

  sprintf("%s %s %s", field, operator)
}

#` Filter on boolean
#'
#' @param field     Field to filter on
#' @param value     Either 'true' or 'false'
#'
#' @return
#' @export
by_boolean <- function(field, value=c('true','false')) {
  value = match.arg(value)
  sprintf("%s eq %s", field, value)
}

#' Combine filters with 'and'
#'
#' @param ...
#'
#' @return
#' @export
filter_and <- function(...) {
  paste0('(', paste(list(...), collapse=' and '),')')
}


#' Combine filters with 'or'
#'
#' @param ...
#'
#' @return
#' @export
filter_or <- function(...) {
  paste0('(', paste(list(...), collapse=' or '),')')
}


#' Join with another entity
#'
#' Join the entity with another entity.
#' See documentation on [website](https://opendata.tweedekamer.nl/documentatie/odata-api) for valid relations.
#' For example, if you go to [ZaakActor](https://opendata.tweedekamer.nl/documentatie/zaakactor), you see that it has a relation to 'Zaak',
#' and in the relation attributes you see that you can join on "Gericht aan", "Indiener", etc.
#' So we can join the entity 'Zaak' with 'ZaakActor' on 'Indiener' (see example below).
#'
#' @param tk_url  A tk_url_builder object (the output of tk_entity)
#' @param entities   The entity (or a vector of entities) to join with.
#' @param relation    filter on a relation attribute.
#'
#' @return
#' @export
#'
#' @examples
#'
#' # The following code joins Zaak on ZaakActor, but including all relations (Indiener, Gericht aan, etc)
#' tk_entity('zaak') %>%
#'  tk_expand('ZaakActor') %>%
#'  tk_list(limit=5)
#'
#' # We can filter on a specific relation, for example 'Indiener':
#' tk_entity('zaak') %>%
#'  tk_expand('ZaakActor', relation='Indiener') %>%
#'  tk_list(limit=5)
#'
#' # Note that the nr of results is the same even when filtering on relation.
#' # This is because the joined entity is nested in the results
#'
#' # You cannot filter the results based on the nexted entity. If you want to get all "Zaak" items
#' # only for a particular ZaakActor, turn the query around
#' tk_entity('ZaakActor') %>%
#'    tk_expand('Zaak') %>%
#'    tk_filter(by_string('Relatie', 'eq', 'Indiener')) %>%
#'    tk_list(limit=5)
tk_expand <- function(tk_url, entities, relation=NULL) {
  entity = paste0(entities, collapse=',')
  if (!is.null(relation)) {
    tk_url$params[['$expand']] = sprintf("%s($filter=relatie eq '%s')", entity, relation)
  } else {
    tk_url$params[['$expand']] = entity
  }
  tk_url
}
