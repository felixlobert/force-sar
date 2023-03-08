import sys
import os
from src import utils
import geopandas as gpd


# read prm file path from console input
prm_file = sys.argv[1]
prm = utils.read_prm(prm_file)


# read tile list from tile file
if prm['FILE_TILE'] != 'NULL':
    tiles = utils.read_til(prm['FILE_TILE'])
else:
    x_range = [int(i) for i in prm['X_TILE_RANGE'].split(' ')]
    x_range = list(range(x_range[0], x_range[1] + 1))
    x_range = [str(i).zfill(4) for i in x_range]

    y_range = [int(i) for i in prm['Y_TILE_RANGE'].split(' ')]
    y_range = list(range(y_range[0], y_range[1] + 1))
    y_range = [str(i).zfill(4) for i in y_range]

    tiles = ['X' + x_tile + '_Y' + y_tile for x_tile in x_range for y_tile in y_range]


# read and filter force grid for tile list
force_grid = gpd.read_file(prm['FORCE_GRID'])
force_grid = force_grid[force_grid['Tile_ID'].isin(tiles)]


# query available scenes from api and filter for orbits from prm file
scenes = utils.get_scenes(
    aoi = force_grid,
    satellite = 'Sentinel1',
    start_date = prm['DATE_RANGE'].split(' ')[0],
    end_date = prm['DATE_RANGE'].split(' ')[1],
    product_type = 'GRD',
    sensor_mode = 'IW',
    processing_level = '1',
    codede = prm['REPO'] == 'CODEDE')

if prm['ORBITS'] != 'NULL':
    orbits = [int(orbit) for orbit in prm['ORBITS'].split(' ')]
    scenes = scenes[scenes['relativeOrbitNumber'].isin(orbits)]


for index, scene in scenes.iterrows():

    # define wkt subset as intersection between scene and tiles as processing extent 
    subset = force_grid.to_crs(epsg=4326).unary_union.intersection(scene['geometry']).envelope.wkt

    # create file name including centroid coords of scene
    date = scene['date'][0:10].replace('-', '')
    base_name = date + '_LEVEL2_' + scene['platform'] + 'I' + scene['orbitDirection'][0] + '_SIG'
    e_coord = str('%g'%(round(scene['centroidLon'] * 10, 0))).zfill(4)
    n_coord = str('%g'%(round(scene['centroidLat'] * 10, 0))).zfill(4)
    base_name = base_name + '_N' + n_coord + '_E' + e_coord
    fname = prm['DIR_ARCHIVE'] + '/'  + base_name + '.tif'

    # create snap gpt command and execute
    graph = '/force-sar/graphs/grd_to_gamma0.xml'
        
    cmd = '/usr/local/snap/bin/gpt ' + graph 
    cmd += ' -Pinput=' + scene['productIdentifier'] + '/manifest.safe'
    cmd += ' -Poutput=' + fname 
    cmd += ' -Pspeckle_filter=\'' + prm['SPECKLE_FILTER'].title() +'\'' 
    cmd += ' -Pfilter_size=' + prm['FILTER_SIZE'] 
    cmd += ' -Presolution=' + prm['RESOLUTION'] 
    cmd += ' -Paoi=\'' + subset + '\''

    os.system(cmd)
