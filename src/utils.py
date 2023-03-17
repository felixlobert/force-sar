import geopandas as gpd
import pandas as pd
import requests
from shapely import wkt
import json
import tempfile
import asf_search
import zipfile
from xml.dom import minidom


def read_prm(prm_file):
    """Read FORCE parameter file and store variables.

    Parameters
    ----------
    prm_file : str
        Path to the parameter file
    
    Returns
    -------
    dictionary
        Containing key value pairs for all variables included in the parameter file.

    """
    # create empty dictionary
    prm = {}

    # iterate over lines in prmfile
    with open(prm_file) as prmfile:
        for line in prmfile:
            
            # skip header, comments, and blank lines
            if line.strip().startswith(('#','+',' ')) or not line.strip():
                continue

            # add name value pairs to dict
            name, value = line.strip().split(' = ')
            prm[name] = value
    
    return prm


def read_til(til_file):
    """Read FORCE tile file.

    Parameters
    ----------
    til_file : str
        Path to the tile file.
    
    Returns
    -------
    list
        Containing tiles present in the tile file.

    """
    tiles = []

    with open(til_file) as tilfile:
        for line in tilfile:
            
            # skip header, comments, and blank lines
            if not line.strip().startswith('X'):
                continue

            tiles.append(line.strip())
    
    return tiles


def get_scenes_creodias(aoi = None, satellite = None, start_date = None, end_date = None, product_type = None, sensor_mode = None, relative_orbit = None, orbit_direction = None, repo = 'CODEDE'):
    """Query metadata for available satellite imagery in the repositories of CODE-DE and Creodias.

    None of the parameters are mandatory.

    Parameters
    ----------
    aoi : geodataframe
        GeoPandas GeoDataFrame defining the geographical extent of the query.
    satellite : str
        The satellite of interest: Sentinel1, Sentinel2, etc.
    start_date: str
        Start of query DD-MM-YYY.
    end_date: str
        End of query DD-MM-YYY.
    product_type: str
        One of IW_GRDH_1S, SLC, etc.
    sensor_mode: str
        One of IW, OCN, etc. (S1 only)
    relative_Orbit: str
        Number of relative orbit (S1 only).
    orbit_direction: str
        Orbit direction: ascending or descending (S1 only).
    repo: str
        Use CODE-DE repository (Germany only; default) or Creodias ['CODEDE', 'CREODIAS'].
    
    Returns
    -------
    geodataframe
        Containing metadata and footprint of images matching the query.

    """
    # define aoi as wkt string
    shape_convex_hull = aoi.to_crs(epsg=4326).unary_union.convex_hull
    aoi_wkt = shape_convex_hull.wkt

    # define api to use
    if repo == 'CODEDE':
        base_url = "https://finder.code-de.org/resto/api/collections/"
    else:
        base_url = "https://datahub.creodias.eu/resto/api/collections/"

    # build query with given search criteria
    query = base_url

    if satellite is not None:
        query += satellite + "/search.json?maxRecords=1000&"
    else:
        query += "search.json?maxRecords=1000&"

    if start_date is not None:
        query += "startDate=" + start_date

    if end_date is not None:
        query += "&completionDate=" + end_date
        
    if product_type is not None:
        query += "&productType=" + product_type

    if relative_orbit is not None:
        query += "&relativeOrbitNumber=" + relative_orbit

    if orbit_direction is not None:
        query += "&orbitDirection=" + orbit_direction.upper()

    if sensor_mode is not None:
        query += "&sensorMode=" + sensor_mode

    if aoi is not None:
        query += "&geometry=" + aoi_wkt

    query += '&sortParam=startDate'
    query += "&processingLevel=LEVEL1"

    # query api and convert response to dataframe
    response = requests.get(query).json()
    df = pd.json_normalize(response['features'])

    # subset columns
    columns_subset = {
        'properties.completionDate': 'date',
        'properties.relativeOrbitNumber': 'relativeOrbitNumber',
        'properties.orbitDirection': 'orbitDirection',
        'properties.productType': 'productType',
        'properties.platform': 'platform',
        'properties.sensorMode': 'sensorMode',
        'properties.centroid.coordinates': 'centroidCoordinates',
        'properties.productIdentifier': 'productIdentifier',
        'properties.gmlgeometry': 'geometry'
    }

    df = df.rename(columns=columns_subset)[[*columns_subset.values()]]

    # split list column
    df[['centroidLon','centroidLat']] = pd.DataFrame(df.centroidCoordinates.tolist(), index = df.index)
    df.pop('centroidCoordinates')

    # parse gmlgeometry into wkt format
    df['geometry'] = df['geometry'].str.replace('<gml:MultiPolygon srsName="EPSG:4326"><gml:polygonMember><gml:Polygon><gml:outerBoundaryIs><gml:LinearRing><gml:coordinates>','POLYGON((')
    df['geometry'] = df['geometry'].str.replace(',',';')
    df['geometry'] = df['geometry'].str.replace(' ',', ')
    df['geometry'] = df['geometry'].str.replace(';',' ')
    df['geometry'] = df['geometry'].str.replace('</gml:coordinates></gml:LinearRing></gml:outerBoundaryIs></gml:Polygon></gml:polygonMember></gml:MultiPolygon>','))')

    # create and return geodataframe
    df['geometry'] = gpd.GeoSeries.from_wkt(df['geometry'])
    gdf = gpd.GeoDataFrame(df, geometry='geometry')
    gdf = gdf.set_crs(epsg=4326)

    return gdf


def get_scenes_asf(aoi = None, start_date = None, end_date = None, relative_orbit = None, orbit_direction = None):
    """Query metadata for available satellite imagery from Alaska Satellite Facility.

    None of the parameters are mandatory.

    Parameters
    ----------
    aoi : geodataframe
        GeoPandas GeoDataFrame defining the geographical extent of the query.
    start_date: str
        Start of query DD-MM-YYY.
    end_date: str
        End of query DD-MM-YYY.
    relative_Orbit: str
        Number of relative orbit.
    orbit_direction: str
        Orbit direction: ascending or descending (S1 only).
    
    Returns
    -------
    geodataframe
        Containing metadata and footprint of images matching the query.

    """
    # define aoi as wkt string
    shape_convex_hull = aoi.to_crs(epsg=4326).unary_union.convex_hull
    aoi_wkt = shape_convex_hull.wkt

    # format orbit direction if set
    if orbit_direction is not None:
        orbit_direction = orbit_direction.upper()

    # define functions parameter that are not none
    params = {
        'intersectsWith': aoi_wkt,
        'start': start_date,
        'end': end_date,
        'relativeOrbit': relative_orbit,
        'flightDirection': orbit_direction
    }
    params = {k:v for k, v in params.items() if v is not None}

    results = asf_search.search(platform='Sentinel-1', 
                         processingLevel='GRD_HD', 
                         beamMode='IW',
                         **params)

    fp = tempfile.NamedTemporaryFile(mode='w')
    with open(fp.name, "w", encoding='utf-8') as f:
        json.dump(results.geojson(), f, ensure_ascii=False, indent=4) 
    gdf = gpd.read_file(fp.name).set_crs(epsg=4326)

    # subset columns
    columns_subset = {
        'stopTime': 'date',
        'pathNumber': 'relativeOrbitNumber',
        'flightDirection': 'orbitDirection',
        'processingLevel': 'productType',
        'platform': 'platform',
        'beamModeType': 'sensorMode',
        'centerLon': 'centroidLon',
        'centerLat': 'centroidLat',
        'url': 'productIdentifier',
        'geometry': 'geometry'
    }

    gdf = gdf.rename(columns=columns_subset)[[*columns_subset.values()]]

    return gdf


def get_metadata(filepath):
    """Get metadata for a zipped S1 scene.

    Parameters
    ----------
    filepath : str
        Path to zipped S1 scene.
    
    Returns
    -------
    tuple
        date, platform, direction, e_coord, n_coord

    """
    # open manifest.safe from zipped S1 scene
    archive = zipfile.ZipFile(filepath, 'r')    
    manifest = archive.open(os.path.basename(filepath)[:-4] + '.SAFE/manifest.safe')
    dom = minidom.parse(manifest)
    
    # derive metadat from filename
    date = os.path.basename(filepath)[17:25]
    platform = os.path.basename(filepath)[0:2]
        
    # derive metadat from xml
    direction = dom.getElementsByTagName('s1:pass')[0].firstChild.nodeValue
    
    coords = dom.getElementsByTagName('gml:coordinates')[0].firstChild.nodeValue
    coords = coords + ' ' + coords.split(' ')[0]
    coords = coords.replace(',',';')
    coords = coords.replace(' ',', ')
    coords = coords.replace(';',' ')
    coords = 'POLYGON((' + coords + '))'

    polygon = shapely.wkt.loads(coords)

    e_coord = str('%g'%(round(polygon.centroid.coords[0][1]* 10, 0))).zfill(4)
    n_coord = str('%g'%(round(polygon.centroid.coords[0][0]* 10, 0))).zfill(4)
    
    return date, platform, direction, e_coord, n_coord