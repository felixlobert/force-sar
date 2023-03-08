# force-sar
This project aims to create a Sentinel-1 SAR data processing module that can be used to integrate SAR data into the [Framework for Operational Radiometric Correction for Environmental monitoring (FORCE)](https://force-eo.readthedocs.io/en/latest/). The project is still in the conception phase and especially intended to be used on platforms that have access to a satellite data repository like a DIAS or the [German CODE-DE cloud environment](https://code-de.org/de/). A submodule to download Sentinel-1 data is planned.

force-sar is based on a module to query scenes of interest based on a number of different search criteria and a [docker container running esa SNAP](https://hub.docker.com/r/mundialis/esa-snap) that takes over the processing of the data with a pre-built but easily customizable S1-GRD to $\gamma^0$ workflow. Search criteria and data are both defined in a FORCE-like parameter file (see example/prm_file.prm).

force-sar uses a custom docker image that is built using the Dockerfile. The module is then started using a bash script (bash/force-sar.sh) together with the user-defined parameter-file (example/prm_file.prm):

```bash
git clone https://github.com/felixlobert/force-sar.git

cd force-sar

docker build -t force-sar .

bash bash/force-sar.sh example/prm_file.prm
```