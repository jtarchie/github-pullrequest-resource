#!/usr/bin/env ruby

require 'octokit'
require 'English'
require 'json'
require_relative 'base'

module Commands
  class In < Commands::Base
    attr_reader :destination

    def initialize(input:, destination:)
      @destination = destination

      super(input: input)
    end

    def output
      deprecation_warning!

      id = pr['number']
      branch_ref = "pr-#{pr['head']['ref']}"

      raise 'PR has merge conflicts' if pr['mergeable'] == false && fetch_merge

      system("git clone --depth 1 #{uri} #{destination} 1>&2")

      raise 'git clone failed' unless $CHILD_STATUS.exitstatus.zero?

      Dir.chdir(destination) do
        raise 'git clone failed' unless system("git fetch -q origin pull/#{id}/#{remote_ref}:#{branch_ref} 1>&2")

        system <<-BASH
          git checkout #{branch_ref} 1>&2
          git submodule update --init --recursive 1>&2
          git config --add pullrequest.url #{pr['html_url']} 1>&2
          git config --add pullrequest.id #{pr['number']} 1>&2
          git config --add pullrequest.branch #{pr['head']['ref']} 1>&2
        BASH
      end

      {
        'version' =>  { 'ref' => ref, 'pr' => id.to_s },
        'metadata' => [{ 'name' => 'url', 'value' => pr['html_url'] }]
      }
    end

    private

    def pr
      @pr ||= Octokit.pull_request(input['source']['repo'], input['version']['pr'])
    end

    def uri
      input['source']['uri'] || "https://github.com/#{input['source']['repo']}"
    end

    def ref
      input['version']['ref']
    end

    def remote_ref
      fetch_merge ? 'merge' : 'head'
    end

    def fetch_merge
      input.fetch('params', {})['fetch_merge']
    end

    def deprecation_warning!
      unless input['source']['every']
        $stderr.puts 'DEPRECATION: Please note that you should update to using `version: every` on your `get` for this resource.'
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  destination = ARGV.shift
  input = JSON.parse(ARGF.read)
  command = Commands::In.new(input: input, destination: destination)
  puts JSON.generate(command.output)
end
