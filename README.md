# force-sar
This project aims to create a Sentinel-1 SAR data processing module that can be used to integrate SAR data into the [Framework for Operational Radiometric Correction for Environmental monitoring (FORCE)](https://force-eo.readthedocs.io/en/latest/) and is still in the conception phase. It is especially intended to be used on platforms that already have a satellite data repository like a DIAS or the [German CODE-DE cloud environment](https://code-de.org/de/), but will also be abled to download the satellite data.

It is based on a module to query scenes of interest and a [docker container running esa SNAP](https://hub.docker.com/r/mundialis/esa-snap) that takes over the processing of the data with a pre-built but easily customizable S1-GRD to $\gamma^0$ workflow.

The docker image is built from the Dockerfile, the module is the started with a bash file (bash/force-sar.sh) and a user-defined parameter-file (data/test_params/prm_file.prm):
```bash
docker build -t force-sar .

sh bash/force-sar.sh data/test_params/prm_file.prm
```