
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tweedekamer

<!-- badges: start -->
<!-- badges: end -->

This package provides bindings for using the [Open Data API of the Dutch
House of
Representatives](https://opendata.tweedekamer.nl/documentatie/odata-api)

## basic example code

## Installation

You can install the development version of tweedekamer from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("kasperwelbers/tweedekamer")
```

## Example

List entities that can be queried

``` r
library(tweedekamer)

tk_entities()
#>  [1] "persoon"                         "persooncontactinformatie"       
#>  [3] "persoongeschenk"                 "persoonloopbaan"                
#>  [5] "persoonnevenfunctie"             "persoonnevenfunctieinkomsten"   
#>  [7] "persoononderwijs"                "persoonreis"                    
#>  [9] "commissie"                       "commissiecontactinformatie"     
#> [11] "commissiezetel"                  "commissiezetelvastpersoon"      
#> [13] "commissiezetelvastvacature"      "commissiezetelvervangerpersoon" 
#> [15] "commissiezetelvervangervacature" "fractie"                        
#> [17] "fractiezetel"                    "fractiezetelpersoon"            
#> [19] "fractiezetelvacature"            "activiteit"                     
#> [21] "activiteitactor"                 "agendapunt"                     
#> [23] "besluit"                         "stemming"                       
#> [25] "zaak"                            "zaakactor"                      
#> [27] "zaal"                            "reservering"                    
#> [29] "document"                        "documentactor"                  
#> [31] "documentversie"                  "kamerstukdossier"               
#> [33] "vergadering"                     "verslag"                        
#> [35] "toezegging"
```

Count items for an entity

``` r
tk_entity('persoon') |>
  tk_count()
#> [1] 4231
```

Filter results

``` r
tk_entity('persoon') |>
  tk_filter(
    tk_string_filter('geslacht', 'eq', 'vrouw')
  ) |>
  tk_count()
#> [1] 530
```

Download results

``` r
data = tk_entity('persoon') |>
  tk_filter(
    tk_string_filter('geslacht', 'eq', 'vrouw')
  ) |>
  tk_list()

nrow(data)
#> [1] 530
```

Fancy filters

``` r
tk_entity('persoon') |>
  tk_filter(
    tk_string_filter('geslacht', 'eq', 'vrouw'),
    tk_or(
      tk_date_filter('geboortedatum', 'lt', '1970-01-01T23:00:00Z'),
      tk_date_filter('geboortedatum', 'gt', '1980-01-01')
    )
  ) |>
  tk_count()
#> [1] 428
```
