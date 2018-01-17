#!/usr/bin/env ruby

require 'json'
require_relative 'base'
require_relative '../repository'

module Commands
  class Check < Commands::Base
    def output
      repo.pull_requests.reject do |pr|
        pr.latest_commit_message.include? '[ci skip]'
      end
    end

    private

    def repo
      @repo ||= Repository.new(name: input.source.repo)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command = Commands::Check.new
  puts JSON.generate(command.output)
end
