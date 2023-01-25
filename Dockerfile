FROM mundialis/esa-snap:8.0-ubuntu

# fix locale error
RUN apt-get update && apt-get -y install locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8     

# important R dependencies
RUN apt-get -y install libssl-dev libcurl4-openssl-dev libxml2-dev

# add repo and install  R >= 4.0
RUN apt-get -y install software-properties-common
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran40/'

RUN apt-get update && apt-get -y install r-base

RUN apt-get -y install libgdal-dev libproj-dev libgeos-dev libudunits2-dev libcairo2-dev libnetcdf-dev

# install R-packges
RUN R -e "install.packages('remotes')"
RUN R -e "remotes::install_github('felixlobert/rcodede@b4ceac7060ab3e1c2bbb5eddf77e8c8727b1c17a')"
RUN R -e "install.packages('parallel')"
RUN R -e "install.packages('lubridate')"
RUN R -e "install.packages('stringr')"

COPY . /force-sar/
WORKDIR /force-sar/
