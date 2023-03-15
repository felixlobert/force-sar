FROM mundialis/esa-snap:9.0-ubuntu

ADD requirements.txt /force-sar/
RUN pip install -r /force-sar/requirements.txt

ADD . /force-sar/
RUN pip install -e /force-sar/.

WORKDIR /force-sar/

RUN chmod +x /force-sar/bin/*
RUN ln -s /force-sar/bin/* /usr/local/bin/