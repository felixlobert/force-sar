import sys
import os
from src import utils
import geopandas as gpd
import pandas as pd
from multiprocessing import Pool


# read prm file path from console input
prm_file = sys.argv[1]
prm = utils.read_prm(prm_file)


# find common tiles from defined range and oprional tile file
x_range = [int(i) for i in prm['X_TILE_RANGE'].split(' ')]
x_range = list(range(x_range[0], x_range[1] + 1))
x_range = [str(i).zfill(4) for i in x_range]

y_range = [int(i) for i in prm['Y_TILE_RANGE'].split(' ')]
y_range = list(range(y_range[0], y_range[1] + 1))
y_range = [str(i).zfill(4) for i in y_range]

tiles = ['X' + x_tile + '_Y' + y_tile for x_tile in x_range for y_tile in y_range]

if prm['FILE_TILE'] != 'NULL':
    tiles_file = utils.read_til(prm['FILE_TILE'])
    tiles = set(tiles).intersection(tiles_file)


# read and filter force grid for tile list
force_grid = gpd.read_file(prm['FORCE_GRID'])
force_grid = force_grid[force_grid['Tile_ID'].isin(tiles)]


# start parallel search for each orbit if orbit(s) set in prm file
if prm['ORBITS'] != 'NULL':

    orbits = prm['ORBITS'].split(' ')
        
    def get_scenes_per_orbit(orbit):

        scenes = utils.get_scenes(
        aoi = force_grid,
        satellite = 'Sentinel1',
        start_date = prm['DATE_RANGE'].split(' ')[0],
        end_date = prm['DATE_RANGE'].split(' ')[1],
        product_type = 'GRD', 
        relative_orbit = orbit,
        sensor_mode = 'IW',
        processing_level = '1',
        repo = prm['REPO'])

        return scenes

    # create the process pool and search for scenes in parallel
    with Pool(int(prm['NTHREAD'])) as pool:
        scenes = pd.concat(pool.map(get_scenes_per_orbit, orbits))

else:

    # query available scenes from api and filter for orbits from prm file
    scenes = utils.get_scenes(
        aoi = force_grid,
        satellite = 'Sentinel1',
        start_date = prm['DATE_RANGE'].split(' ')[0],
        end_date = prm['DATE_RANGE'].split(' ')[1],
        product_type = 'GRD',
        sensor_mode = 'IW',
        processing_level = '1',
        repo = prm['REPO'])


for index, scene in scenes.iterrows():

    # define wkt subset as bbox of intersection between scene and tiles as processing extent 
    subset = force_grid.to_crs(epsg=4326).unary_union.intersection(scene['geometry']).envelope.wkt

    # create file name including centroid coords of scene
    date = scene['date'][0:10].replace('-', '')
    base_name = date + '_LEVEL2_' + scene['platform'] + 'I' + scene['orbitDirection'][0] + '_SIG'
    e_coord = str('%g'%(round(scene['centroidLon'] * 10, 0))).zfill(4)
    n_coord = str('%g'%(round(scene['centroidLat'] * 10, 0))).zfill(4)
    base_name = base_name + '_N' + n_coord + '_E' + e_coord
    fname = prm['DIR_ARCHIVE'] + '/'  + base_name + '.tif'

    if os.path.exists(fname):
        continue

    # create snap gpt command and execute
    cmd = '/usr/local/snap/bin/gpt /force-sar/graphs/grd_to_gamma0.xml'
    cmd += ' -Pinput=' + scene['productIdentifier'] + '/manifest.safe'
    cmd += ' -Poutput=' + fname 
    cmd += ' -Pspeckle_filter=\'' + prm['SPECKLE_FILTER'].title() +'\'' 
    cmd += ' -Pfilter_size=' + prm['FILTER_SIZE'] 
    cmd += ' -Presolution=' + prm['RESOLUTION'] 
    cmd += ' -Paoi=\'' + subset + '\''

    # define processing parameters
    cmd += ' -q ' + prm['NTHREAD']
    cmd += ' -J-Xms2G -J-Xmx' + prm['MAX_MEMORY'] + 'G -c ' + str('%g'%(float(prm['MAX_MEMORY'])*0.7)) +'G'
    cmd += ' -Dsnap.dataio.bigtiff.compression.type=LZW'
    cmd += ' -Dsnap.dataio.bigtiff.tiling.width=512'
    cmd += ' -Dsnap.dataio.bigtiff.tiling.height=512'

    os.system(cmd)
