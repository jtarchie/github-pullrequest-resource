#!/usr/bin/env ruby

require 'json'
require_relative 'base'
require_relative '../repository'

module Commands
  class Check < Commands::Base
    def output
      repo.pull_requests
    end

    private

    def repo
      @repo ||= Repository.new(name: input.source.repo)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  command = Commands::Check.new
  puts JSON.generate(command.output)
end
