FROM mundialis/esa-snap:9.0-ubuntu

# fix locale error
RUN apt-get update && apt-get -y install locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

# add user and give docker sock permission
RUN useradd --create-home --shell /bin/bash force-sar
RUN chown -R force-sar /root/
WORKDIR /home/force-sar

# install gdal
RUN apt-get update && \
    apt-get -y install software-properties-common && \
    add-apt-repository ppa:ubuntugis/ubuntugis-unstable && \
    apt-get update && \
    apt-get -y install gdal-bin && \
    apt-get -y install libgdal-dev && \
    export CPLUS_INCLUDE_PATH=/usr/include/gdal && \
    export C_INCLUDE_PATH=/usr/include/gdal && \
    pip install --no-cache-dir GDAL==3.0.4

# install parallel
RUN apt-get -y install parallel
RUN yes 'will cite' | parallel --citation

# install python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# add source code and install
COPY . .
RUN pip install --no-cache-dir -e .

# retrieve force-cube.sh from davidfrantz/force
RUN apt-get -y install curl 
RUN curl -o bin/force-cube https://raw.githubusercontent.com/davidfrantz/force/main/bash/force-cube.sh

# make scripts executable and copy to /usr/local/bin/
RUN chmod +x bin/*
RUN cp bin/* /usr/local/bin/

USER force-sar
ENTRYPOINT [ "force-sar" ]