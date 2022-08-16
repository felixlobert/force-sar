#!/bin/bash

# set command input as path for parameterfile
PRM_FILE=$1

# grep directories from prm-file, remove whitespace and define in environment
DIRECTORIES=$(cat $PRM_FILE | grep '^DIR\|^FILE\|^RESOLUTION\|^NTHREAD' | grep -v 'NULL' | sed -r '/[^=]+=[^=]+/!d' | sed -r 's/\s+=\s/=/g')
eval $DIRECTORIES

# start docker container with esa SNAP and R and connect paths given in prm file
docker run \
    -t -d \
    --name force-sar-container \
    -v $PRM_FILE:/force-sar/data/test_params/prm_file.prm \
    -v $DIR_ARCHIVE:$DIR_ARCHIVE \
    -v $DIR_LOWER:$DIR_LOWER \
    -v $DIR_REPO:$DIR_REPO \
    -v $DIR_DEM:/root/.snap/auxdata/dem/SRTM\ 1Sec\ HGT \
    -v $DIR_ORBIT:/root/.snap/auxdata/Orbits/ \
    -v $FILE_TILE:$FILE_TILE \
    force-sar

# query and process data inside docker container
docker exec force-sar-container Rscript R/force-sar.R

gid=$(id -g $USER)
uid=$(id -u $USER)

docker exec force-sar-container groupadd --gid $gid $USER
docker exec force-sar-container useradd --uid $uid --gid $gid $USER
docker exec force-sar-container chown -R $USER:$USER $DIR_ARCHIVE

# stop container
docker stop force-sar-container
docker rm force-sar-container

# # define unique date and orbit pairs from processed scenes
ACQUISITIONS=$(ls $DIR_ARCHIVE | grep '.tif' | cut -f1-3 -d'_' | uniq)

# loop over date orbit combinations to create a mosaic and tile into existing force cube
for ACQUISITION in $ACQUISITIONS
do
    gdalbuildvrt -vrtnodata -9999 -srcnodata -9999 $DIR_ARCHIVE/${ACQUISITION}_GAM.vrt $DIR_ARCHIVE/$ACQUISITION*.tif

    force-cube -o $DIR_LOWER -n -9999 -t Int16 -r near -j $NTHREAD -s $RESOLUTION $DIR_ARCHIVE/${ACQUISITION}_GAM.vrt 
done


