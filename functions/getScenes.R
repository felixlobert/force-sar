#' Query scenes from CODE-DE EO Finder API
#'
#' Returns metadata for satellite imagery that matches several input criteria
#'
#' @param aoi Area of interest for the query. Has to be an sf object with polygonal or point geometry. In case of a point geometry, the buffer argument has to be set.
#' @param bufferDist Buffer around the AOI in meters. Defaults to 0.
#' @param startDate Starting date for the query of format "YYYY-MM-DD".
#' @param endDate End date for query.
#' @param codede If TRUE (default) use CODE-DE repository covering Germany, if FALSE use CREODIAS for worldwide coverage including Landsat data.
#' @param satellite Satellite to query from. One of "Sentinel1", "Sentinel2" etc. If none is chosen, all available results are returned.
#' @param productType Product type to query. One of "SLC", "GRD", "CARD-INF6", "CARD-BS", "CARD-BS-MC", "L3-WASP"... Only considered if set.
#' @param sensorMode Sensor mode for Sentinel-1. One of "IW", "EW", ... Only considered if set.
#' @param orbitDirection Direction of satellite orbit. One of "ascending" or "descending". Only considered if set.
#' @param relativeOrbitNumber Relative orbit number. Only considered if set.
#' @param view logical indicating if the queried scenes should be visualized with mapview. Defaults to FALSE.
#'
#' @return sf object containing footprints and metadata for all queried scenes.
#' @export
#'
#' @examples
#' # example AOI
#' aoi <- c(10.441054, 52.286959) %>%
#'   sf::st_point() %>%
#'   sf::st_sfc(crs = 4326)
#'
#' # scenes for aoi and given criteria
#' scenes <-
#'   getScenes(
#'     aoi = aoi,
#'     startDate = "2019-01-01",
#'     endDate = "2019-01-15",
#'     satellite = "Sentinel1",
#'     productType = "SLC",
#'     view = TRUE
#'   )
getScenes <-
  function(aoi,
           bufferDist = NULL,
           startDate = NULL,
           endDate = NULL,
           codede = TRUE,
           satellite = NULL,
           productType = NULL,
           sensorMode = NULL,
           orbitDirection = NULL,
           relativeOrbitNumber = NULL,
           view = FALSE) {

    # get epsg code of utm zone for given aoi
    aoi.epsg <-
      aoi %>%
      sf:: st_transform(4326) %>%
      sf::st_coordinates() %>%
      data.frame() %>%
      dplyr::slice(1) %>%
      dplyr::mutate(epsg = 32700 - round((45 + Y) / 90, 0) * 100 + round((183 + X) / 6, 0)) %>%
      dplyr::pull(epsg)

    # buffer aoi by given distance / buffer with 1m if POINT and no distance is set
    if(!is.null(bufferDist)){
      aoi.processed <-
        aoi %>%
        sf::st_transform(aoi.epsg) %>%
        sf::st_buffer(bufferDist) %>%
        sf::st_transform(4326)
    } else if(sf::st_geometry_type(aoi, by_geometry = F) == "POINT"){
      aoi.processed <-
        aoi %>%
        sf::st_transform(aoi.epsg) %>%
        sf::st_buffer(1) %>%
        sf::st_transform(4326)
    } else{
      aoi.processed <-
        aoi %>%
        sf::st_transform(4326)
    }

    aoi.wkt <-
      aoi.processed %>%
      sf::st_bbox() %>%
      sf::st_as_sfc() %>%
      sf::st_as_text(digits = 15) %>%
      gsub(", ", "%2C", .) %>%
      gsub("POLYGON ", "POLYGON", .) %>%
      gsub(" ", "+", .)

    url = paste0(
      "https://finder.code-de.org/",
      if(codede)
        paste0("resto/api/collections/")
      else
        paste0("resto-creodias/api/collections/"),
      if (!is.null(satellite))
        paste0(satellite,"/"),
      "search.json?maxRecords=1000&location=all&sortParam=startDate&sortOrder=descending&status=all&dataset=ESA-DATASET",
      if (!is.null(orbitDirection))
        paste0("&orbitDirection=", orbitDirection),
      if (!is.null(startDate))
        paste0("&startDate=", startDate, "T00%3A00%3A00Z"),
      if (!is.null(endDate))
        paste0("&completionDate=", endDate, "T23%3A59%3A59Z"),
      if (!is.null(productType))
        paste0("&productType=", productType),
      if (!is.null(sensorMode))
        paste0("&sensorMode=", sensorMode),
      if (!is.null(relativeOrbitNumber))
        paste0("&relativeOrbitNumber=", relativeOrbitNumber),
      if (!is.null(aoi))
        paste0("&geometry=", aoi.wkt)
    )

    scenes <- url %>%
      httr::GET() %$%
      content %>%
      base::rawToChar() %>%
      jsonlite::fromJSON() %$%
      features$properties %>%
      dplyr::mutate(
        lon = sapply(.$centroid$coordinates, `[[`, 1),
        lat = sapply(.$centroid$coordinates, `[[`, 2)
      ) %>%
      dplyr::mutate(wkt = gsub(
        ".*<gml:coordinates>(.+)</gml:coordinates>.*",
        "\\1",
        gmlgeometry
      )) %>%
      dplyr::mutate(wkt = gsub(",", ";", wkt)) %>%
      dplyr::mutate(wkt = gsub(" ", ", ", wkt)) %>%
      dplyr::mutate(wkt = gsub(";", " ", wkt)) %>%
      dplyr::mutate(wkt = paste0("POLYGON (( ", wkt, " ))")) %>%
      dplyr::select(
          date = startDate,
          platform,
          relativeOrbitNumber,
          orbitDirection,
          productType,
          centroidLat = lat,
          centroidLon = lon,
          productPath = productIdentifier,
          footprint = wkt
        ) %>%
      tidyr::separate(date, c("date", NA), sep = "T") %>%
      dplyr::mutate(date = as.Date(date)) %>%
      dplyr::arrange(date) %>%
      sf::st_as_sf(wkt = "footprint") %>%
      sf::`st_crs<-`(sf::st_crs(4326)) %>%
      dplyr::mutate(numberAoiGeoms = sf::st_contains_properly(sf::st_transform(., aoi.epsg), sf::st_transform(aoi.processed, aoi.epsg)) %>% lengths) %>%
      dplyr::select(date, platform, productType, orbitDirection, relativeOrbitNumber, centroidLat, centroidLon, productPath, numberAoiGeoms, footprint) %>%
      dplyr::arrange(date, relativeOrbitNumber) %>%
      dplyr::mutate(date = as.Date(date))

    if (view == T) {
      print(mapview::mapview(scenes, alpha.regions = .15, map.types = "Esri.WorldImagery",
                             zcol = "relativeOrbitNumber") +
              mapview::mapview(aoi, color = "black", col.regions = "white", alpha.regions = .5,
                               legend = FALSE))
    }

    return(scenes)
  }
