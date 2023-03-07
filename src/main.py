import sys
from src import utils
import geopandas as gpd

# read prm file path from console input
prm_file = sys.argv[1]
prm_file = '/home/eouser/projects/force-sar/data/test_params/prm_file.prm'
prm = utils.read_prm(prm_file)

# read tile list from tile file
if prm['FILE_TILE'] != 'NULL':
    tiles = utils.read_til(prm['FILE_TILE'])
else:
    tiles = [('X' + x_tile.zfill(4) + '_' + 'Y' + y_tile.zfill(4)) for x_tile in prm['X_TILE_RANGE'].split(' ') for y_tile in prm['Y_TILE_RANGE'].split(' ')]

force_grid = gpd.read_file(prm['FORCE_GRID'])
force_grid = force_grid[force_grid['Tile_ID'].isin(tiles)]

scenes = utils.get_scenes(
    aoi = force_grid,
    satellite = 'Sentinel1',
    start_date = prm['DATE_RANGE'][1],
    end_date = prm['DATE_RANGE'][2],
    product_type = 'GRD',
    sensor_mode = 'IW',
    processing_level = '1',
    codede = prm['REPO'] == 'CODEDE')

  {if(!ORBITS == 'NULL') filter(., relativeOrbitNumber %in% stringr::str_split(ORBITS, ' ')[[1]]) else .} %>%
  st_transform(st_crs(force.grid)) %>% 
  filter(st_intersects(., force.grid) %>% lengths() > 0) %>% 
  filter(stringr::str_detect(productPath, '_IW_GRDH_'))