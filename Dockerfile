FROM mundialis/esa-snap:9.0-ubuntu

# fix locale error
RUN apt-get update && apt-get -y install locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

# install docker
RUN apt-get -y install curl && curl -fsSL https://get.docker.com | sh

# add user and give docker sock permission
RUN useradd --create-home --shell /bin/bash force-sar
RUN usermod -aG docker force-sar
# RUN chmod 666 /var/run/docker.sock
WORKDIR /home/force-sar

# install python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# add source code and install
COPY . .
RUN pip install -e .

# make scripts executable and copy to /usr/local/bin/
RUN chmod +x bin/*
RUN cp bin/* /usr/local/bin/

USER force-sar
# ENTRYPOINT [ "force-sar" ]