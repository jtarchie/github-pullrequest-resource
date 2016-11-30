#!/usr/bin/env ruby

require 'json'
require_relative 'base'
require_relative '../repository'

module Commands
  class Check < Commands::Base
    def output
      if return_all_versions?
        repo.pull_requests
      else
        next_pull_request
      end
    end

    private

    def return_all_versions?
      input.source.every == true
    end

    def next_pull_request
      pull_request = repo.next_pull_request(
        id: input.version.pr,
        sha: input.version.ref
      )

      if pull_request
        [pull_request]
      else
        []
      end
    end

    def repo
      @repo ||= Repository.new(name: input.source.repo)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  command = Commands::Check.new
  puts JSON.generate(command.output)
end
