FROM mundialis/esa-snap:9.0-ubuntu

# fix locale error
RUN apt-get update && apt-get -y install locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

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