FROM mundialis/esa-snap:9.0-ubuntu

RUN useradd --create-home --shell /bin/bash force-sar
WORKDIR /home/force-sar

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN pip install -e .

RUN chmod +x bin/*
RUN cp bin/* /usr/local/bin/

USER force-sar

ENTRYPOINT [ "force-sar" ]