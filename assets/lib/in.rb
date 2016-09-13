#!/usr/bin/env ruby
destination = ARGV.shift

require 'rubygems'
require 'json'
require_relative 'common'
require 'octokit'
require 'English'

def uri
  input['source']['uri'] || "https://github.com/#{input['source']['repo']}"
end

def ref
  input['version']['ref']
end

def remote_ref
  params['fetch_merge'] ? 'merge' : 'head'
end

$stderr.puts 'DEPRECATION: Please note that you should update to using `version: every` on your `get` for this resource.'

pr = Octokit.pull_request(input['source']['repo'], input['version']['pr'])
id = pr['number']
branch_ref = "pr-#{pr['head']['ref']}"

raise 'PR has merge conflicts' if pr['mergeable'] == false && params['fetch_merge']

system("git clone --depth 1 #{uri} #{destination} 1>&2")

raise 'git clone failed' unless $CHILD_STATUS.exitstatus.zero?

Dir.chdir(destination) do
  raise 'git clone failed' unless system("git fetch -q origin pull/#{id}/#{remote_ref}:#{branch_ref} 1>&2")
  system("git checkout #{branch_ref} 1>&2")
  system('git submodule update --init --recursive 1>&2')
  system("git config --add pullrequest.url #{pr['html_url']} 1>&2")
  system("git config --add pullrequest.id #{pr['number']} 1>&2")
  system("git config --add pullrequest.branch #{pr['head']['ref']} 1>&2")
end

puts JSON.generate(version:  { ref: ref, pr: id.to_s },
                   metadata: [{ name: 'url', value: pr['html_url'] }])
