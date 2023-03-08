#!/bin/bash

if [[ -z $1 ]]
then
    echo error: path to parameterfile needs to be set.
    exit 1
fi

# set command input as path for parameterfile
if [[ "$1" = /* ]]
then
    PRM_FILE=$1
else
    PRM_FILE=$PWD/$1
fi

# grep directories from prm-file, remove whitespace and define in environment
DIRECTORIES=$(cat $PRM_FILE | grep '^DIR\|^FORCE_GRID\|^FILE\|^RESOLUTION\|^NTHREAD' | grep -v 'NULL' | sed -r '/[^=]+=[^=]+/!d' | sed -r 's/\s+=\s/=/g')
eval $DIRECTORIES

# start docker container with esa SNAP
docker run \
    -t -d \
    --name force-sar-container \
    -v $PRM_FILE:$PRM_FILE \
    -v $DIR_ARCHIVE:$DIR_ARCHIVE \
    -v $DIR_LOWER:$DIR_LOWER \
    -v $FORCE_GRID:$FORCE_GRID \
    -v $DIR_REPO:$DIR_REPO \
    -v $FILE_TILE:$FILE_TILE \
    -v $DIR_DEM:/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT \
    -v $DIR_ORBIT:/root/.snap/auxdata/Orbits/ \
    force-sar

# query and process data inside docker container
docker exec force-sar-container python3 src/main.py $PRM_FILE

gid=$(id -g $USER)
uid=$(id -u $USER)

docker exec force-sar-container groupadd --gid $gid $USER
docker exec force-sar-container useradd --uid $uid --gid $gid $USER
docker exec force-sar-container chown -R $USER:$USER $DIR_ARCHIVE

# stop container
docker stop force-sar-container
docker rm force-sar-container

# start force docker container for mosaicing and cubing files
docker run \
    -t -d \
     --name force-container \
    -v $DIR_LOWER:$DIR_LOWER \
    -v $DIR_ARCHIVE:$DIR_ARCHIVE \
    -u $(id -u):$(id -g) \
    davidfrantz/force:3.7.10 \
    /bin/bash

# define unique date and orbit pairs from processed scenes
ACQUISITIONS=$(ls $DIR_ARCHIVE | grep '.tif' | cut -f1-3 -d'_' | uniq)

# loop over date orbit combinations to create a mosaic and tile into existing force cube
for ACQUISITION in $ACQUISITIONS
do
    docker exec force-container gdalbuildvrt -vrtnodata -9999 -srcnodata -9999 $DIR_ARCHIVE/${ACQUISITION}_GAM.vrt $DIR_ARCHIVE/$ACQUISITION*.tif

    docker exec force-container force-cube -o $DIR_LOWER -n -9999 -t Int16 -r near -j $NTHREAD -s $RESOLUTION $DIR_ARCHIVE/${ACQUISITION}_GAM.vrt 
done

# stop container
docker stop force-container
docker rm force-container
