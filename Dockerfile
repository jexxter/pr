FROM alpine:3.3
MAINTAINER ninthwalker <ninthwalker@gmail.com>

VOLUME /config
EXPOSE 6878

ENV BUILD_PACKAGES ruby ruby-dev
# removed bash and curl-dev
#ENV RUBY_PACKAGES
ENV BUNDLER_VERSION 1.12.3

#copy nowShowing files
COPY root/ /
WORKDIR /opt/gem

RUN apk add --no-cache \
$BUILD_PACKAGES \
ruby-json \
make \
gcc
# ruby-io-console \
#ruby-irb 
#ruby-rake
#ruby-rdoc
# $RUBY_PACKAGES \
# may need build-base (includes make, gcc and others, but is large (like 100mb)

RUN gem install bundler -v $BUNDLER_VERSION --no-ri --no-rdoc && \
bundle config --global silence_root_warning 1 && \
bundle install

WORKDIR /config

CMD ["ruby", "-run", "-e", "httpd", ".", "-p", "6878"]
