FROM alpine:3.3
MAINTAINER ninthwalker <ninthwalker@gmail.com>

VOLUME /config
EXPOSE 6878

ENV RUBY_PACKAGES ruby ruby-dev ruby-io-console
ENV BUNDLER_VERSION 1.12.3

#copy app files
COPY root/ / && \
s6-overlay/ /
WORKDIR /opt/gem

RUN apk add --no-cache \
$RUBY_PACKAGES \
curl-dev \
make \
gcc

RUN gem install bundler -v $BUNDLER_VERSION --no-ri --no-rdoc && \
bundle config --global silence_root_warning 1 && \
bundle install

WORKDIR /config

ENTRYPOINT ["/init"]
CMD ["ruby", "-run", "-e", "httpd", ".", "-p", "6878"]
