
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

## Basic Usage

List entities that can be queried

``` r
library(tweedekamer)

tk_entities()
#>  [1] "persoon"                         "persooncontactinformatie"       
#>  [3] "persoongeschenk"                 "persoonloopbaan"                
#>  [5] "persoonnevenfunctie"             "persoonnevenfunctieinkomsten"   
#>  [7] "persoononderwijs"                "persoonreis"                    
#>  [9] "activiteit"                      "activiteitactor"                
#> [11] "agendapunt"                      "besluit"                        
#> [13] "commissie"                       "commissiecontactinformatie"     
#> [15] "commissiezetel"                  "commissiezetelvastpersoon"      
#> [17] "commissiezetelvastvacature"      "commissiezetelvervangerpersoon" 
#> [19] "commissiezetelvervangervacature" "document"                       
#> [21] "documentactor"                   "documentversie"                 
#> [23] "fractie"                         "fractiezetel"                   
#> [25] "fractiezetelpersoon"             "fractiezetelvacature"           
#> [27] "kamerstukdossier"                "reservering"                    
#> [29] "stemming"                        "toezegging"                     
#> [31] "toezegging"                      "vergadering"                    
#> [33] "verslag"                         "zaak"                           
#> [35] "zaakactor"                       "zaal"                           
#> [37] "resource"                        "identiteit"
```

Get attributes and relations for an entity

``` r
tk_attributes("persoon")
#> $attributes
#>  [1] "persoon"           "nummer"            "titels"           
#>  [4] "initialen"         "tussenvoegsel"     "achternaam"       
#>  [7] "voornamen"         "roepnaam"          "geslacht"         
#> [10] "functie"           "geboortedatum"     "geboorteplaats"   
#> [13] "geboorteland"      "overlijdensdatum"  "overlijdensplaats"
#> [16] "woonplaats"        "land"              "fractielabel"     
#> 
#> $relations
#> character(0)
```

Count items for an entity

``` r
tk_entity('persoon') |>
  tk_count()
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?top=1&$count=true&$format=application/json;odata.metadata=none
#> [1] 4231
```

Filter results

``` r
tk_entity('persoon') |>
  tk_filter(
    by_string('geslacht', 'eq', 'vrouw')
  ) |>
  tk_count()
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?$filter=geslacht%20eq%20'vrouw'&top=1&$count=true&$format=application/json;odata.metadata=none
#> [1] 530
```

Download results

``` r
data = tk_entity('persoon') |>
  tk_filter(
    by_string('geslacht', 'eq', 'vrouw')
  ) |>
  tk_list()
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?$filter=geslacht%20eq%20'vrouw'&$count=true&$format=application/json;odata.metadata=minimal
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?$filter=geslacht%20eq%20%27vrouw%27&$count=true&$format=application%2Fjson%3Bodata.metadata%3Dminimal&$skip=250
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?$filter=geslacht%20eq%20%27vrouw%27&$count=true&$format=application%2Fjson%3Bodata.metadata%3Dminimal&$skip=500

nrow(data)
#> [1] 530
```

Fancy filters

``` r
tk_entity('persoon') |>
  tk_filter(
    by_string('geslacht', 'eq', 'vrouw'),
    filter_or(
      by_date('geboortedatum', 'lt', '1970-01-01T23:00:00Z'),
      by_date('geboortedatum', 'gt', '1980-01-01')
    )
  ) |>
  tk_count()
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/persoon?$filter=geslacht%20eq%20'vrouw'%20and%20(geboortedatum%20lt%201970-01-01T23:00:00Z%20or%20geboortedatum%20gt%201980-01-01)&top=1&$count=true&$format=application/json;odata.metadata=none
#> [1] 428
```

Expand (join) entities

``` r
tk_entity('ZaakActor') |>
  tk_filter(by_string('ActorFractie', 'eq', 'VVD'), 
            by_string('relatie', 'eq', 'Indiener')) |>
  tk_expand('Zaak') |>
  tk_list(limit=5)
#> https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/zaakactor?$filter=ActorFractie%20eq%20'VVD'%20and%20relatie%20eq%20'Indiener'&$expand=Zaak&$top=5&$count=true&$format=application/json;odata.metadata=minimal
#> # A tibble: 5 × 28
#>   Id          Zaak_Id ActorNaam ActorFractie Functie Relatie SidActor Persoon_Id
#>   <chr>       <chr>   <chr>     <chr>        <chr>   <chr>   <chr>    <chr>     
#> 1 8dca9b64-2… 7a137f… C.N.A. N… VVD          Tweede… Indien… S-1-365… 93ace320-…
#> 2 2914a292-3… c4be0d… J.H. ten… VVD          Tweede… Indien… S-1-365… 3dbbf804-…
#> 3 72006250-9… 8d592c… J.Z.C.M.… VVD          Tweede… Indien… S-1-365… 97ffe642-…
#> 4 fe9c19fc-2… 35852d… G.A. van… VVD          Tweede… Indien… S-1-365… e6e673f5-…
#> 5 bcaddf2b-a… 8ef639… B. Visser VVD          Tweede… Indien… S-1-365… c955972d-…
#> # ℹ 20 more variables: Fractie_Id <chr>, GewijzigdOp <chr>,
#> #   ApiGewijzigdOp <chr>, Verwijderd <lgl>, Zaak.Id <chr>, Zaak.Nummer <chr>,
#> #   Zaak.Soort <chr>, Zaak.Titel <chr>, Zaak.Status <chr>,
#> #   Zaak.Onderwerp <chr>, Zaak.GestartOp <chr>, Zaak.Organisatie <chr>,
#> #   Zaak.Vergaderjaar <chr>, Zaak.Volgnummer <int>, Zaak.Afgedaan <lgl>,
#> #   Zaak.GrootProject <lgl>, Zaak.Kabinetsappreciatie <chr>,
#> #   Zaak.GewijzigdOp <chr>, Zaak.ApiGewijzigdOp <chr>, Zaak.Verwijderd <lgl>
```
