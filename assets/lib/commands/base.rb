require 'faraday'
require 'octokit'
require_relative '../input'

# httpclient and excon are the only Faraday adpater which support
# the no_proxy environment variable atm
::Faraday.default_adapter = :httpclient

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
