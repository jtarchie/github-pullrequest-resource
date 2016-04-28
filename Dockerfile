FROM alpine

RUN apk add --update \
  ruby \
  perl \
  jq \
  git \
  openssh-client \
  ruby-json \
  ca-certificates
RUN gem install octokit httpclient --no-rdoc --no-ri

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*
