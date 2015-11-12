FROM ruby

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD / /opt/resource-tests/
RUN cd /opt/resource-tests/ && \
    bundle && \
    rspec
