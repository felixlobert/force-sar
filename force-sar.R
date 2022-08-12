library(rcodede)
library(sf)
library(dplyr)
library(tidyr)


# load parameter-file and assign as variables
prm <-
  read.delim(
    "prm_file.prm",
    sep = "=",
    strip.white = T,
    comment.char = "#",
    row.names = NULL
  )

for (i in 1:nrow(prm)) {
  assign(prm[i, 1], prm[i, 2])
}



# load force-grid and filter for tiles from prm-file
if (!FILE_TILE == "NULL") {
  
  tiles <- read.delim(FILE_TILE, skip = 1, header = F)[, 1]
  
  force.grid <- "force_grid/FORCE_GRIDS_germany_EPSG3035.shp" %>% 
    st_read(quiet = T) %>%
    filter(Name %in% tiles)
  
} else {
  
  force.grid <- "force_grid/FORCE_GRIDS_germany_EPSG3035.shp" %>% 
    st_read(quiet = T) %>%
    separate(col = Name, sep = c(3, 5, 9), into = c(NA, "X", NA, "Y"), remove = F) %>%
    filter(
      X %in% stringr::str_split(X_TILE_RANGE, " ")[[1]][1]:stringr::str_split(X_TILE_RANGE, " ")[[1]][2],
      Y %in% stringr::str_split(Y_TILE_RANGE, " ")[[1]][1]:stringr::str_split(Y_TILE_RANGE, " ")[[1]][2]
    )
  
}



# query scenes for given parameters
scenes <-
  getScenes(aoi = force.grid,
            startDate = stringr::str_split(DATE_RANGE, " ")[[1]][1],
            endDate = stringr::str_split(DATE_RANGE, " ")[[1]][2],
            satellite = "Sentinel1",
            productType = "GRD") %>%
  st_transform(st_crs(force.grid))


for(i in 1:nrow(scenes)){
  
  scene <- scenes[i,]
  
  
  
  fname <- paste0(
    DIR_ARCHIVE, "/",
    format(scene$date, "%Y%m%d"),
    "_",
    stringr::str_pad(scene$relativeOrbitNumber, width = 3, side = "left", pad = "0"),
    "_",
    scene$platform,
    ifelse(scene$orbitDirection == "ascending", "IA", "ID"),
    "_N",
    stringr::str_pad(round(scene$centroidLat, 1)*10, width = 3, side = "left", pad = "0"),
    "_E",
    stringr::str_pad(round(scene$centroidLon, 1)*10, width = 3, side = "left", pad = "0"),
    ".tif"
  )
  
  
  
  if(file.exists(fname)) next
  
  
  extents_overlap = TRUE
  
  tryCatch(
    subset <- force.grid %>%
      summarise() %>%
      st_intersection(scene) %>%
      sf::st_transform(4326) %>%
      sf::st_bbox() %>%
      sf::st_as_sfc() %>%
      sf::st_as_text(digits=15),
    error = function(e) extents_overlap <<- FALSE)
  
  if(!extents_overlap) next
  
  
  graph <- "graphs/grd_to_gamma0.xml"
  
  
  cmd <-
    paste0(
      "/usr/local/snap/bin/gpt ",
      graph,
      " -Pinput=", scene$productPath, "/manifest.safe",
      " -Poutput=", fname,
      " -Pspeckle_filter=", stringr::str_to_sentence(SPECKLE_FILTER),
      " -Pfilter_size=", FILTER_SIZE,
      " -Presolution=", RESOLUTION,
      " -Paoi=\"", subset,"\""
    )
  
  
  system(cmd)
  
}
