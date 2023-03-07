import geopandas as gpd
import pandas as pd
import requests
from shapely import wkt
import os


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


def get_scenes(aoi = None, satellite = None, start_date = None, end_date = None, product_type = None, sensor_mode = None, relative_orbit = None, orbit_direction = None, processing_level = "1", codede = False):
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
    processing_level: str
        1 for GRD, SLC, etc., 2 for CARD-BS.
    codede: bool
        Use CODE-DE repository (Germany only) of Creodias.
    
    Returns
    -------
    geodataframe
        Containing metadata and footprint of images matching the query.

    """
    # define aoi as wkt string
    shape_convex_hull = aoi.to_crs(epsg=4326).unary_union.convex_hull
    aoi_wkt = shape_convex_hull.wkt

    # define api to use
    if codede:
        base_url = "https://finder.code-de.org/resto/api/collections/"
    else:
        base_url = "https://datahub.creodias.eu/resto/api/collections/"

    # build query with given search criteria
    query = base_url

    if satellite is not None:
        query = query + satellite + "/search.json?"
    else:
        query = query + "search.json?"

    if start_date is not None:
        query = query + "startDate=" + start_date

    if end_date is not None:
        query = query + "&endDate=" + end_date
        
    if product_type is not None:
        query = query + "&productType=" + product_type

    if processing_level is not None:
        query = query + "&processingLevel=LEVEL" + processing_level

    if relative_orbit is not None:
        query = query + "&relativeOrbitNumber=" + relative_orbit

    if orbit_direction is not None:
        query = query + "&orbitDirection=" + orbit_direction.upper()

    if sensor_mode is not None:
        query = query + "&sensorMode=" + sensor_mode

    if aoi is not None:
        query = query + "&geometry=" + aoi_wkt

    # query api and convert response to dataframe
    response = requests.get(query).json()
    df = pd.json_normalize(response['features'])

    # subset columns
    columns_subset = {
        'properties.completionDate': 'date',
        'properties.relativeOrbitNumber': 'relativeOrbitNumber',
        'properties.orbitDirection': 'orbitDirection',
        'properties.productType': 'productType',
        'properties.processingLevel': 'processingLevel',
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

    return gdf
