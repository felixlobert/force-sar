#' Estimate the interferometric coherence
#'
#' Coherence estimation for two corresponding Sentinel-1 SLC scenes
#'
#' @param scene1 Path of first Sentinel-1 scene for coherence estimation.
#' @param scene2 Path of second Sentinel-1 scene.
#' @param outputDirectory Directory for the output file.
#' @param fileName Name of the output file.
#' @param resolution Spatial resolution of the output raster in meters.
#' @param polarisation Polarisations to be processed. One of "VH", "VV", or "VV,VH". Defaults to "VV,VH".
#' @param swath Swath to be processed. One of "IW1", "IW2", "IW3" or "all".
#' @param firstBurst First burst index from the chosen swath. Between 1 and 9. Only relevant if swath != "all".
#' @param lastBurst Last burst index. Has to be higher than or equal to first burst. Only relevant if swath != "all".
#' @param aoi sf object for the area of interest.
#' @param aoiBuffer Buffer around aoi in meters. Defaults to 0.
#' @param numCores Number of CPUs to be used in the process. Chosen by SNAP if not set.
#' @param maxMemory Amount of memory to be used in GB. Chosen by SNAP if not set.
#' @param crs Coordinate reference system to use for output of format "EPSG:XXXX". Defaults to automatic UTM/WGS84 if not set.
#' @param execute logical if command for esa SNAP gpt shall be executed. If FALSE the command is printed instead.
#' @param return logical if processed raster or stack shall be returned.
#' @param BigTIFF logical if output should be written as BigTIFF.
#' @param docker logical if a dockerized version of SNAP (mundialis/esa-snap:ubuntu) should be used. Make sure docker is installed and can be run by the user. The image is pulled automatically from dockerhub on first execution.
#' @param sudo logical if command should be executed or returned with superuser rights
#'
#' @return
#' @export
#'
#' @examples
#' # example AOI
#' aoi <- c(10.441054, 52.286959) %>%
#'   sf::st_point() %>%
#'   sf::st_sfc(crs = 4326)
#'
#' # scenes for AOI and given criteria
#' scenes <-
#'   getScenes(
#'     aoi = aoi,
#'     startDate = "2019-01-01",
#'     endDate = "2019-01-15",
#'     satellite = "Sentinel1",
#'     productType = "SLC"
#'   ) %>%
#'   dplyr::filter(relativeOrbitNumber == 117)
#'
#' estimateCoherence(
#'   scene1 = scenes$productPath[2],
#'   scene2 = scenes$productPath[1],
#'   fileName = "test.tif",
#'   resolution = 30,
#'   aoi = aoi,
#'   execute = FALSE)
estimateCoherence <-
  function(scene1,
           scene2,
           outputDirectory = getwd(),
           fileName,
           resolution,
           polarisation = "VV,VH",
           swath = "all",
           firstBurst = 1,
           lastBurst = 9,
           aoi = NULL,
           aoiBuffer = NULL,
           numCores = NULL,
           maxMemory = NULL,
           crs = "AUTO:42001",
           execute = FALSE,
           return = FALSE,
           BigTIFF = FALSE,
           docker = FALSE,
           sudo = FALSE) {

    if(BigTIFF) format = "GeoTIFF-BigTIFF" else format = "GeoTIFF"

    if(is.null(aoi)){

      if(swath == "all"){

        graph <-
          system.file("extdata", "coherenceGraphAllSwaths.xml", package = "rcodede")

        cmd <- paste0(
          if(docker) paste0("docker run -v /codede:/codede -v /codede/auxdata/orbits/:/root/.snap/auxdata/Orbits/ -v \"/codede/auxdata/SRTMGL1/dem/\":\"/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT/\" -v $HOME:$HOME -u root --rm --entrypoint /usr/local/snap/bin/gpt mundialis/esa-snap:ubuntu "),
          if(!docker) paste0("gpt "),
          graph,
          " -Pinput1=", scene1, "/manifest.safe",
          " -Pinput2=", scene2, "/manifest.safe",
          " -Poutput=", outputDirectory, "/", fileName,
          " -Ppolarisation=", polarisation,
          " -Presolution=", resolution,
          " -Pformat=", format,
          " -Pcrs=", crs,
          if(!is.null(numCores)) paste0(" -q ", numCores),
          if(!is.null(maxMemory)) paste0(" -J-Xms2G -J-Xmx", maxMemory, "G", " -c ", round(maxMemory * 0.7), "G")
        )

      } else{

        graph <-
          system.file("extdata", "coherenceGraphOneSwath.xml", package = "rcodede")

        cmd <- paste0(
          if(docker) paste0("docker run -v /codede:/codede -v /codede/auxdata/orbits/:/root/.snap/auxdata/Orbits/ -v \"/codede/auxdata/SRTMGL1/dem/\":\"/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT/\" -v $HOME:$HOME -u root --rm --entrypoint /usr/local/snap/bin/gpt mundialis/esa-snap:ubuntu "),
          if(!docker) paste0("gpt "),
          graph,
          " -Pinput1=", scene1, "/manifest.safe",
          " -Pinput2=", scene2, "/manifest.safe",
          " -Poutput=", outputDirectory, "/", fileName,
          " -Pswath=", swath,
          " -Ppolarisation=", polarisation,
          " -PfirstBurst=", firstBurst,
          " -PlastBurst=", lastBurst,
          " -Presolution=", resolution,
          " -Pformat=", format,
          " -Pcrs=", crs,
          if(!is.null(numCores)) paste0(" -q ", numCores),
          if(!is.null(maxMemory)) paste0(" -J-Xms2G -J-Xmx", maxMemory, "G", " -c ", round(maxMemory * 0.7), "G")
        )
      }

    } else{

      aoi.epsg <-
        aoi %>%
        sf:: st_transform(4326) %>%
        sf::st_coordinates() %>%
        data.frame() %>%
        dplyr::slice(1) %>%
        dplyr::mutate(epsg = 32700 - round((45 + Y) / 90, 0) * 100 + round((183 + X) / 6, 0)) %>%
        dplyr::pull(epsg)

      subset <- aoi %>%
        sf::st_transform(aoi.epsg) %>%
        {if(!is.null(aoiBuffer)) sf::st_buffer(., aoiBuffer) else .} %>%
        sf::st_transform(4326) %>%
        sf::st_bbox() %>%
        sf::st_as_sfc() %>%
        sf::st_as_text(digits=15)

      if(swath == "all"){

        graph <-
          system.file("extdata", "coherenceGraphAllSwathsSubset.xml", package = "rcodede")

        cmd <- paste0(
          if(docker) paste0("docker run -v /codede:/codede -v /codede/auxdata/orbits/:/root/.snap/auxdata/Orbits/ -v \"/codede/auxdata/SRTMGL1/dem/\":\"/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT/\" -v $HOME:$HOME -u root --rm --entrypoint /usr/local/snap/bin/gpt mundialis/esa-snap:ubuntu "),
          if(!docker) paste0("gpt "),
          graph,
          " -Pinput1=", scene1, "/manifest.safe",
          " -Pinput2=", scene2, "/manifest.safe",
          " -Poutput=", outputDirectory, "/", fileName,
          " -Ppolarisation=", polarisation,
          " -Presolution=", resolution,
          " -Pformat=", format,
          " -Pcrs=", crs,
          " -Paoi=\"", subset,"\"",
          if(!is.null(numCores)) paste0(" -q ", numCores),
          if(!is.null(maxMemory)) paste0(" -J-Xms2G -J-Xmx", maxMemory, "G", " -c ", round(maxMemory * 0.7), "G")
        )

      } else{

        graph <-
          system.file("extdata", "coherenceGraphOneSwathSubset.xml", package = "rcodede")

        cmd <- paste0(
          if(docker) paste0("docker run -v /codede:/codede -v /codede/auxdata/orbits/:/root/.snap/auxdata/Orbits/ -v \"/codede/auxdata/SRTMGL1/dem/\":\"/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT/\" -v $HOME:$HOME -u root --rm --entrypoint /usr/local/snap/bin/gpt mundialis/esa-snap:ubuntu "),
          if(!docker) paste0("gpt "),
          graph,
          " -Pinput1=", scene1, "/manifest.safe",
          " -Pinput2=", scene2, "/manifest.safe",
          " -Poutput=", outputDirectory, "/", fileName,
          " -Pswath=", swath,
          " -Ppolarisation=", polarisation,
          " -PfirstBurst=", firstBurst,
          " -PlastBurst=", lastBurst,
          " -Presolution=", resolution,
          " -Pformat=", format,
          " -Pcrs=", crs,
          " -Paoi=\"", subset,"\"",
          if(!is.null(numCores)) paste0(" -q ", numCores),
          if(!is.null(maxMemory)) paste0(" -J-Xms2G -J-Xmx", maxMemory, "G", " -c ", round(maxMemory * 0.7), "G")
        )
      }
    }

    if(execute){
      if(sudo){
        system(paste0("sudo ", cmd))
      } else{
        system(cmd)
      }
    } else{
      if(sudo){
        cat(paste0("sudo ", cmd))
      } else{
        cat(cmd)
      }
    }

    if(return){
      raster::stack(paste0(outputDirectory, "/", fileName)) %>%
        return()
    }
  }
