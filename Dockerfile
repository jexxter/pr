FROM phusion/baseimage:0.9.18
MAINTAINER ninthwalker

# Set correct environment variables
ENV HOME /root 
ENV DEBIAN_FRONTEND noninteractive 
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8 
ENV LANGUAGE en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

#copy plexReport files
COPY root/ /

#add new web_email_body.erb & start python web server
RUN mkdir -p /etc/my_init.d && \
mkdir -p /etc/service/httpserver
ADD /root/add_web_body.sh /etc/my_init.d/add_web_body.sh
ADD /root/httpserver.sh /etc/service/httpserver/run

# Configure user nobody to match unRAID's settings.
 RUN \
 usermod -u 99 nobody && \
 usermod -g 100 nobody && \
 usermod -d /home nobody && \
 chown -R nobody:users /home

RUN \
add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu/ trusty universe multiverse" && \
add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates universe multiverse" && \
apt-get update -q && \
apt-get install -qy ruby ruby-dev git make gcc && \
apt-get clean -y && \
rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* && \
cd /opt/gem && \
gem install bundler -v 1.12.3 && \
bundle install

VOLUME /config
EXPOSE 8080

