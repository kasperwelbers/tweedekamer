
.onLoad <- function(libname, pkgname) {
  .tk_get_entities <<- memoise::memoise(download_entities)
  .tk_get_attributes <<- memoise::memoise(download_attributes)
}

download_entities <- function() {
  url = 'https://raw.githubusercontent.com/TweedeKamerDerStaten-Generaal/OpenDataPortaal/master/xsd/tkData-v1-0.xsd'
  xml = httr2::request(url) |>
    httr2::req_perform() |>
    httr2::resp_body_raw() |>
    xml2::read_xml()

  entities = xml2::xml_find_all(xml, './/xs:include') |>
    xml2::xml_attr('schemaLocation')


  tibble::tibble(url = paste0('https://raw.githubusercontent.com/TweedeKamerDerStaten-Generaal/OpenDataPortaal/master/xsd/', entities),
                 entity = gsub('\\.xsd', '',  gsub('.*-', '', entities)))
}

download_attributes <- function(entity) {
  entities = .tk_get_entities()
  if (!entity %in% entities$entity) {
    stop("Invalid entity. See tk_entities() for valid entities.")
  }
  url = entities$url[entities$entity == entity]
  xml = httr2::request(url) |>
    httr2::req_perform() |>
    httr2::resp_body_raw() |>
    xml2::read_xml()

  relations = xml2::xml_find_all(xml, './/xs:element[contains(@type, "referentie")]') |>
    xml2::xml_attr('name')
  attributes = xml2::xml_find_all(xml, './/xs:element[not(contains(@type, "referentie"))]') |>
    xml2::xml_attr('name')

  list(attributes = attributes, relations = relations)
}

#' Get list of entities
#'
#' @return A character vector with the entities
#' @export
tk_entities <- function() {
  .tk_get_entities()$entity
}


#' Get list of attributes for a given entity
#'
#' @param entity The entity to get attributes for
#' @return A character vector with the entities
#' @export
tk_attributes <- function(entity) {
  entity = tolower(entity)
  if (!entity %in% tk_entities()) {
    stop("Invalid entity. See tk_entities() for valid entities.")
  }

  .tk_get_attributes(entity)
}
