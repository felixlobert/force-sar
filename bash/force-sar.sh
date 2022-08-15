#!/bin/bash

# set command input as path for parameterfile
PRM_FILE=$1

# grep directories from prm-file, remove whitespace and define in environment
DIRECTORIES=$(cat $PRM_FILE | grep '^DIR\|^FILE' | grep -v 'NULL' | sed -r '/[^=]+=[^=]+/!d' | sed -r 's/\s+=\s/=/g')
eval $DIRECTORIES

# run docker container with correct paths
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

docker exec force-sar-container Rscript R/force-sar.R

docker stop force-sar-container
docker rm force-sar-container
