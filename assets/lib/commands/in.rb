#!/usr/bin/env ruby

require 'octokit'
require 'English'
require 'json'
require_relative 'base'

module Commands
  class In < Commands::Base
    attr_reader :destination

    def initialize(destination:, input: Input.instance)
      @destination = destination

      super(input: input)
    end

    def output
      id = pr['number']
      branch_ref = "pr-#{pr['head']['ref']}"
      depth = input.source.master_depth || 1

      raise 'PR has merge conflicts' if pr['mergeable'] == false && fetch_merge

      system("git clone --depth #{depth} #{uri} #{destination} 1>&2")

      raise 'git clone failed' unless $CHILD_STATUS.exitstatus.zero?

      Dir.chdir(destination) do
        raise 'git clone failed' unless system("git fetch -q origin pull/#{id}/#{remote_ref}:#{branch_ref} 1>&2")

        system <<-BASH
          git checkout #{branch_ref} 1>&2
          git submodule update --init --recursive 1>&2
          git config --add pullrequest.url #{pr['html_url']} 1>&2
          git config --add pullrequest.id #{pr['number']} 1>&2
          git config --add pullrequest.branch #{pr['head']['ref']} 1>&2
          git config --add pullrequest.basebranch #{pr['base']['ref']} 1>&2
        BASH
      end

      {
        'version' =>  { 'ref' => ref, 'pr' => id.to_s },
        'metadata' => [{ 'name' => 'url', 'value' => pr['html_url'] }]
      }
    end

    private

    def pr
      @pr ||= Octokit.pull_request(input.source.repo, input.version.pr)
    end

    def uri
      input.source.uri || "https://github.com/#{input.source.repo}"
    end

    def ref
      input.version.ref
    end

    def remote_ref
      fetch_merge ? 'merge' : 'head'
    end

    def fetch_merge
      input.params.fetch_merge
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  destination = ARGV.shift
  command = Commands::In.new(destination: destination)
  puts JSON.generate(command.output)
end
