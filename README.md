# force-sar

## Intro

force-sar is a module that enables the integration of Sentinel-1 Synthetic Aperture Radar (SAR) data into the [Framework for Operational Radiometric Correction for Environmental monitoring (FORCE)](https://force-eo.readthedocs.io/en/latest/) by David Frantz. force-sar provides the capability to create SAR data cubes with consistent radiometric and geometric properties, covering large regions and time periods. This enables users to perform multi-sensor and multi-temporal analyses. 

With force-sar, Sentinel-1 Ground Range Detected (GRD) acquisitions are preprocessed to analysis-ready backscatter coefficient data, including calibration, speckle filtering, and terrain correction. The analysis-ready SAR data are then seamlessly ingested into your existing FORCE data cube allowing for convenient scalability of operations and applying the whole [FORCE Higher Level](https://force-eo.readthedocs.io/en/latest/components/higher-level/index.html) functionality. With force-sar, you have the flexibility to use GRD data from a mounted satellite data repository or download the data directly to your machine. 

Please note that force-sar is currently in development, and further enhancements are ongoing. Contributions from the community are welcomed to help shape and improve the functionality of force-sar in the future.

## Main components

force-sar consists of four main components:

1. query
    - The query module allows you to search for Sentinel-1 data that matches your criteria in terms of space and time. You can specify search criteria and retrieve metadata, including footprints, of the scenes that match your query. The data can be downloaded from the Alaskan Satellite Facility (ASF) or, if you are working on [CODE-DE](https://code-de.org/de/), [EO-Lab](https://eo-lab.org/de/) or Creodias, directly used from the mounted satellite data repository. You can also specify additional processing parameters, such as orbit direction, to narrow down your search.
2. download
    - In case you don't have access to a mounted satellite data repository, the download module allows you to automatically download the queried Sentinel-1 scenes from the [Alaska Satellite Facility - Distributed Active Archive Center](https://asf.alaska.edu/data-sets/sar-data-sets/sentinel-1/) using your user credentials. The downloaded products will be stored in a Level 0 (unprocessed products) archive.
3. process
    - The processing module uses an [esa SNAP](https://step.esa.int/main/download/snap-download/) [docker image](https://hub.docker.com/r/mundialis/esa-snap) to process the downloaded or mounted Sentinel-1 data with a pre-built, but easily customizable, S1-GRD to $\gamma^0$ workflow (`graphs/grd_to_gamma0.xml`). Within the processing workflow, the S1 data is already subsetted to match the extent of your defined data cube, saving disk space when working with small study areas. Processed data will be stored in a Level 1 (processed but not yet tiled) archive. You can specify additional processing parameters, such as calibration options and speckle filtering.
4. cube
    - In the cube module, the processed S1 data is seamlessly integrated into your FORCE datacube using the power of [gdal vrts](https://gdal.org/drivers/raster/vrt.html) and the FORCE built-in [force-cube](https://force-eo.readthedocs.io/en/latest/components/auxilliary/cube.html) functionality.

## Setup

force-sar comes as completely dockerized stand-alone command line interface. The latest image can be pulled from dockerhub and tested with:
```bash
docker pull felixlobert/force-sar
docker run felixlobert/force-sar
```
Keep in mind that all force-sar functions are performed within the Docker container. As a result, you need to properly mount the directories that contain the data you want to use with force-sar when executing the `docker run` command. To streamline the process and make it more user-friendly, you may want to add a customized alias, similar to the example provided, to your `~/.bashrc` file for seamless and convenient usage of force-sar.

```bash
alias force-sar=' \
  docker run \
  -u "$(id -u):$(id -g)" \
  -v $HOME:$HOME \
  -ti \
  --rm \
  felixlobert/force-sar'
```

## Usage

Using the force-sar functions is similar to using FORCE. To get started, prepare a parameter file and provide it to one of the functions. You can create a parameter file with `force-sar parameter`. To learn more about the required arguments and options for a function, you can add `--help` to the command. For example:
```bash
force-sar query --help
```

### ASF credentials

When using ASF as data source, you have to provide your own credentials. They can be stored in a file named `~/.asf_credentials` in your home directory that should contain the ASF Portal username and password in separate lines. The file name is ".asf_credentials" (with a dot in front), which makes it a hidden file.

The file should have the following format:
```
username
password
```
For example, if the username is "johndoe" and the password is "mypassword", the contents of the file would be:
```
johndoe
mypassword
```
Please note that this file contains sensitive information, so it should be kept confidential and protected from unauthorized access.

It is also possible to enter your credentials directly within the command when running `force-sar download`. More information on thus can be taken from `force-sar download --help`.

## Acknowledgements

force-sar greatly benefits from the features and the data cube concept of the [Framework for Operational Radiometric Correction for Environmental monitoring (FORCE)](https://force-eo.readthedocs.io/en/latest/) by David Frantz, and acknowledges its contribution to the project.