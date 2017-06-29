require 'faraday'
require 'octokit'
require 'faraday-http-cache'

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.use Octokit::Response::RaiseError
  # httpclient and excon are the only Faraday adpater which support
  # the no_proxy environment variable atm
  builder.adapter :httpclient
end
Octokit.middleware = stack

require_relative '../input'

module Commands
  class Base
    attr_reader :input

    def initialize(input: Input.instance)
      @input = input
      setup_octokit
    end

    private

    def setup_octokit
      Octokit.auto_paginate = true
      Octokit.connection_options[:ssl] = { verify: false } if input.source.no_ssl_verify
      Octokit.configure do |c|
        c.api_endpoint = input.source.api_endpoint if input.source.api_endpoint
        c.access_token = input.source.access_token
      end
    end
  end
end
