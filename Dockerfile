FROM alpine as resource

RUN apk add --update ca-certificates
RUN apk add --update curl
RUN apk add --update git
RUN apk add --update jq
RUN apk add --update openssh-client
RUN apk add --update perl
RUN apk add --update ruby
RUN apk add --update ruby-json
RUN gem install octokit activesupport httpclient faraday-http-cache --no-rdoc --no-ri

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*
ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh

FROM resource as tests
COPY . /resource

RUN apk add --update \
    ruby-bundler \
    ruby-io-console \
    ruby-dev \
    openssl-dev \
    alpine-sdk
RUN cd /resource && bundle install && bundle exec rspec

FROM resource
