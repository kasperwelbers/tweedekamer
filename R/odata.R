
.onLoad <- function(libname, pkgname) {
  tk_entities <<- memoized_get_entities()
}

memoized_get_entities <- function() {
  cache <- NULL
  function() {
    if (is.null(cache)) {
      entities_url = 'https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0'
      entities = httr2::request(entities_url) |>
        httr2::req_perform() |>
        httr2::resp_body_json()

      cache <<- sapply(entities$value, function(x) tolower(x$name))
    }
    cache
  }
}



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
  tk_url = sprintf("https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/%s", entity)
  structure(tk_url, class = "tk_url")
}

#' Count the number of results for a query
#'
#' @param tk_url
#'
#' @return a number
#' @export
#'
#' @examples
tk_count <- function(tk_url) {
  if (!grepl('\\?', tk_url)) {
    tk_url = paste0(tk_url, '?$count=true&top=1')
  } else {
    tk_url = paste0(tk_url, '&$count=true&top=1')
  }
  tk_url = URLencode(tk_url)

  res = httr2::request(tk_url) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
  res$`@odata.count`
}

#' Get list of results for query
#'
#' @param tk_url  A tk_url object
#' @param top     Maximum number of results to return. Maximum is 250.
#' @param skip    Number of results to skip.
#'
#' @return A tibble with the results
#' @export
#'
#' @examples
tk_list <- function(tk_url, top=NULL, skip=NULL) {
  if (!grepl('\\?', tk_url)) {
    tk_url <- paste0(tk_url, '?')
  } else {
    tk_url <- paste0(tk_url, '&')
  }
  if (is.null(top)) {
    tk_url <- paste0(tk_url, "$count=true")
  } else {
    if (top > 250) stop("Maximum top is 250")
    tk_url <- paste0(tk_url, "$top=", top)
  }
  if (!is.null(skip)) {
    tk_url <- paste0(tk_url, "&$skip=", skip)
  }
  tk_url = URLencode(tk_url)

  first_page <- httr2::request(tk_url) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (!is.null(top)) {
    return(dplyr::bind_rows(first_page$value))
  }

  rows <- list()
  rows[['']] <- dplyr::bind_rows(first_page$value)
  n <- first_page$`@odata.count`
  nextlink <- first_page$`@odata.nextLink`

  pb <- progress::progress_bar$new(total = n)
  pb$tick(length(first_page$value))
  while (!is.null(nextlink)) {
    res = httr2::request(nextlink) |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    pb$tick(length(res$value))
    rows[['']] = dplyr::bind_rows(res$value)
    nextlink = res$`@odata.nextLink`
  }

  dplyr::bind_rows(rows)
}



#' Add a filter
#'
#' @param tk_url  A tk_url object
#' @param ...     Filters to apply. Use tk_string_filter, tk_date_filter, tk_number_filter, tk_boolean_filter, tk_and, tk_or
#'
#' @return
#' @export
#'
#' @examples
#' tk_entity('persoon') %>%
#'   tk_filter(tk_string_filter('geslacht', 'eq', 'vrouw')) %>%
#'   tk_count()
#'
#' tk_entity('persoon') %>%
#'   tk_filter(
#'     tk_string_filter('geslacht', 'eq', 'vrouw'),
#'     tk_or(
#'       tk_date_filter('geboortedatum', 'lt', '1970-01-01T23:00:00Z'),
#'       tk_date_filter('geboortedatum', 'gt', '1980-01-01')
#'     )
#'   ) %>%
#'   tk_count()
tk_filter <- function(tk_url, ...) {
  filter = paste(list(...), collapse=' and ')
  if ('?' %in% tk_url) {
    paste0(tk_url, '&$filter=', filter)
  } else {
    paste0(tk_url, '?$filter=', filter)
  }
}

#' Filter on string value
#'
#' @param field     Field to filter on
#' @param operator  Operator to use. One of 'eq', 'contains', 'startswith', 'endswith'
#' @param value     string value
#'
#' @return
#' @export
#'
#' @examples
tk_string_filter <- function(field, operator, value) {
  if (!operator %in% c('eq','contains','startswith','endswith')) stop("Invalid operator")
  if (operator == 'eq') return(sprintf("%s %s '%s'", field, operator, value))
  sprintf("%s(%s) '%s'", operator, field, value)
}

#` Filter on date value
#'
#' @param field     Field to filter on
#' @param operator  Operator to use. One of 'eq', 'lt', 'gt'
#' @param value     Date value as a string in the format 'YYYY-MM-DD' or 'YYYY-MM-DDTHH:MM:SSZ'
#'
#' @return
#' @export
#'
#' @examples
tk_date_filter <- function(field, operator, value) {
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
#'
#' @examples
tk_number_filter <- function(field, operator, value) {
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
#'
#' @examples
tk_boolean_filter <- function(field, value=c('true','false')) {
  value = match.arg(value)
  sprintf("%s eq %s", field, value)
}

#' Combine filters with 'and'
#'
#' @param ...
#'
#' @return
#' @export
#'
#' @examples
tk_and <- function(...) {
  paste0('(', paste(list(...), collapse=' and '),')')
}

#' Combine filters with 'or'
#'
#' @param ...
#'
#' @return
#' @export
#'
#' @examples
tk_or <- function(...) {
  paste0('(', paste(list(...), collapse=' or '),')')
}

