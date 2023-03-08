FROM mundialis/esa-snap:9.0-ubuntu

COPY . /force-sar/
WORKDIR /force-sar/

RUN pip install -r requirements.txt