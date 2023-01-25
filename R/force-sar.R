library(rcodede)
library(sf)
library(dplyr)
library(tidyr)


# load parameter-file and assign as variables
prm <-
  read.delim(
    "data/test_params/prm_file.prm",
    sep = "=",
    strip.white = T,
    comment.char = "#",
    row.names = NULL
  )

for (i in seq_len(nrow(prm))) {
  assign(prm[i, 1], prm[i, 2])
}



# load force-grid and filter for tiles from prm-file
if (!FILE_TILE == "NULL") {
  
  tiles <- read.delim(FILE_TILE, skip = 1, header = F)[, 1]
  
  force.grid <- FORCE_GRID %>% 
    st_read(quiet = T) %>%
    filter(Tile_ID %in% tiles)
  
} else {
  
  force.grid <- FORCE_GRID %>% 
    st_read(quiet = T) %>%
    filter(
      Tile_X %in% stringr::str_split(X_TILE_RANGE, " ")[[1]][1]:stringr::str_split(X_TILE_RANGE, " ")[[1]][2],
      Tile_Y %in% stringr::str_split(Y_TILE_RANGE, " ")[[1]][1]:stringr::str_split(Y_TILE_RANGE, " ")[[1]][2]
    )
  
}



# query scenes for given parameters
scenes <-
  getScenes(aoi = force.grid,
            startDate = stringr::str_split(DATE_RANGE, " ")[[1]][1],
            endDate = stringr::str_split(DATE_RANGE, " ")[[1]][2],
            satellite = "Sentinel1", codede = DIR_REPO == "/codede",
            productType = "GRD") %>%
  {if(!ORBITS == "NULL") filter(., relativeOrbitNumber %in% stringr::str_split(ORBITS, " ")[[1]]) else .} %>%
  st_transform(st_crs(force.grid)) %>% 
  filter(st_intersects(., force.grid) %>% lengths() > 0) %>% 
  filter(stringr::str_detect(productPath, "_IW_GRDH_"))



for(i in seq_len(nrow(scenes))){
  
  scene <- scenes[i,]
  
  fname <- paste0(
    DIR_ARCHIVE, "/",
    format(scene$date, "%Y%m%d"),
    "_LEVEL2_",
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
      sf::st_bbox() %>%
      sf::st_as_sfc() %>%
      sf::st_transform(4326) %>%
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
