# force-sar

## Intro
This project aims to create a Sentinel-1 SAR data processing module that can be used to integrate SAR data into the [Framework for Operational Radiometric Correction for Environmental monitoring (FORCE)](https://force-eo.readthedocs.io/en/latest/) and is still in the conception phase.

Right now, force-sar is capable of processing $\gamma^0$ backscatter coefficient from Ground Rage Detected (GRD) Sentinel-1 data. It is possible to either directly use data from a mounted satellite data repository or download the data to your machine.

## Main components

force-sar consists of four main components:

1. query
    - A number of search criteria are defined to search for Sentinel-1 data matching your need of data in space and time. Data can either be downloaded from the [Alaskan Satellite Facility (ASF)](https://asf.alaska.edu/data-sets/sar-data-sets/sentinel-1/) or - in case you are working on [CODE-DE](https://code-de.org/de/), [EO-Lab](https://eo-lab.org/de/) or Creodias - directly be used from the mounted satellite data repository.
    The query module produces a geojson file, showing you the footprints and additional metadata of the scenes you queried.
2. download
    - In case you don't have access to a mounted satellite data repository, this module downloads the queried S1 scenes from ASF using your user credentials. The downloaded products will be stored in a Level 0 unprocessed product archive.
3. process
    - Now [esa SNAP](https://hub.docker.com/r/mundialis/esa-snap) takes over the processing of the downloaded or mounted S1 data with a pre-built but easily customizable S1-GRD to $\gamma^0$ workflow. Within the processing workflow, the S1 data is already subsetted to match the extent of your defined data cube extent to save disk space when working with small study areas. Processed data will be stored in a Level 1 processed but not yet tiled archive.
4. cube
    - In this last module, the power of gdal vrts and the FORCE built-in force-cube functionality are used to seamlessly integrate the processed S1 data into your datacube.

## Usage

force-sar comes as completely dockerized stand-alone command line interface. The latest image can be pulled from dockerhub and tested with
```bash
docker pull felixlobert/force-sar
docker run felixlobert/force-sar
```
all force-sar functions will subsequently be run inside a container.

It might be handy to add this or a similar alias to your ~/.bashrc for a more convenient usage of force-sar.
```bash
alias dforce-sar=' \
  docker run \
  -v $PWD:$PWD \
  --user "$(id -u):$(id -g)" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/group:/etc/group:ro \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  -w $PWD \
  -ti \
  --rm \
  felixlobert/force-sar'
```
Note that it is important to mount your docker.sock to the container since force-sar itself needs to start a docker container with davidfrantz/force during the cubing module.

The usage of the force-sar functions is quite similar to using FORCE. You prepare a parameter file that is then simply provided to one of the functions. An example parameter file can be found under `example/prm_file.prm`. To see a short description and which arguments and options are needed by a function, simply add `--help` to the command, e.g.:
```bash
dforce-sar query --help
```
## Acknowledgements
Like many other projects, this one benefits greatly from the features and the data cube concept of the Framework for Operational Radiometric Correction for Environmental monitoring (FORCE) by David Frantz.