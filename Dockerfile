#start with ubuntu
FROM ubuntu:12.04

#install packages (apache2)
# Install pre-requisites
ENV DEBIAN_FRONTEND noninteractive

ADD sources.list /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -yq curl vim build-essential libxml2-dev libssl-dev libapache2-mod-perl2 libapache2-mod-perl2-dev libgd2-noxpm libgd2-noxpm-dev unzip
#install CPAN minus
RUN curl -L http://cpanmin.us | perl - --self-upgrade

#install required perl modules
ADD all_modules.txt /root/all_modules.txt
RUN for x in $(cat /root/all_modules.txt); do cpanm $x; done

#add apache config
ADD apache.conf /etc/apache2/conf.d/morph.conf

#add Alpheios modules
ADD src /var/www/perl

WORKDIR /var/www/perl/Alpheios

RUN curl -u username:password -o bama2.zip -L https://github.com/alpheios-project/bama2/archive/master.zip && unzip bama2.zip && mv bama2-master bama2

# Default command	
CMD ["apachectl", "-D", "FOREGROUND"]

# Ports
EXPOSE 80
