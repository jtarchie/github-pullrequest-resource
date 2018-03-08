#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'json'
require 'shellwords'
require_relative 'base'

module Commands
  class In < Commands::Base
    attr_reader :destination

    def initialize(destination:, input: Input.instance)
      @destination = destination

      super(input: input)
    end

    def output
      id         = pr['number']
      branch_ref = "pr-#{pr['head']['ref']}"

      raise 'PR has merge conflicts' if pr['mergeable'] == false && fetch_merge

      system("git clone #{depth_flag} --branch #{pr['base']['ref']} #{uri} #{destination} 1>&2")

      raise 'git clone failed' unless $CHILD_STATUS.exitstatus.zero?

      Dir.chdir(File.join(destination, '.git')) do
        File.write('url', pr['html_url'])
        File.write('id', pr['number'])
        File.write('body', pr['body'])
        File.write('branch', pr['head']['ref'])
        File.write('base_branch', pr['base']['ref'])
        File.write('base_sha', pr['base']['sha'])
        File.write('userlogin', pr['user']['login'])
        File.write('head_sha', pr['head']['sha'])
      end

      Dir.chdir(destination) do
        raise 'git clone failed' unless system("git fetch #{depth_flag} -q origin pull/#{id}/#{remote_ref}:#{branch_ref} 1>&2")

        system <<-BASH
          git checkout #{branch_ref} 1>&2
          git config --add pullrequest.url #{pr['html_url'].to_s.shellescape} 1>&2
          git config --add pullrequest.id #{pr['number'].to_s.shellescape} 1>&2
          git config --add pullrequest.body #{pr['body'].to_s.shellescape} 1>&2
          git config --add pullrequest.branch #{pr['head']['ref'].to_s.shellescape} 1>&2
          git config --add pullrequest.basebranch #{pr['base']['ref'].to_s.shellescape} 1>&2
          git config --add pullrequest.basesha #{pr['base']['sha'].to_s.shellescape} 1>&2
          git config --add pullrequest.userlogin #{pr['user']['login'].to_s.shellescape} 1>&2
        BASH

        case input.params.git.submodules
        when 'all', nil
          system("git submodule update --init --recursive #{depth_flag} 1>&2")
        when Array
          input.params.git.submodules.each do |path|
            system("git submodule update --init --recursive #{depth_flag} #{path} 1>&2")
          end
        end

        unless input.params.git.disable_lfs
          system('git lfs fetch 1>&2')
          system('git lfs checkout 1>&2')
        end
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

    def depth_flag
      if depth = input.params.git.depth
        "--depth #{depth}"
      else
        ''
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  destination = ARGV.shift
  command = Commands::In.new(destination: destination)
  puts JSON.generate(command.output)
end
