FROM alpine:3.3
MAINTAINER ninthwalker <ninthwalker@gmail.com>

ENV UPDATED_ON 14MAR2017
ENV RUBY_PACKAGES ruby ruby-dev ruby-json ruby-io-console
ENV BUNDLER_VERSION 1.12.3

VOLUME /config
EXPOSE 6878

#copy app files
#COPY root/ s6-overlay/ /
WORKDIR /config

RUN apk add --no-cache \
$RUBY_PACKAGES \
curl-dev \
make \
gcc \
tar \
gzip

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.19.1.1/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

RUN \
cd /opt/gem && \
gem install bundler -v $BUNDLER_VERSION --no-ri --no-rdoc && \
bundle config --global silence_root_warning 1 && \
bundle install

ENTRYPOINT ["/init"]
CMD ["ruby", "-run", "-e", "httpd", ".", "-p", "6878"]
