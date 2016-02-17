#!/usr/bin/env ruby
# encoding: utf-8

destination = ARGV.shift

require 'rubygems'
require 'json'
require 'octokit'
require_relative 'common'

def uri
  input['source']['uri'] || "https://github.com/#{input['source']['repo']}"
end

def ref
  input['version']['ref']
end

pr = Octokit.pull_request(input['source']['repo'], input['version']['pr'])
id = pr['number']

system("git clone --depth 1 #{uri} #{destination} 1>&2")
Dir.chdir(destination) do
  system('git submodule update --init --recursive 1>&2')
  system("git fetch -q origin pull/#{id}/head:pr-#{id} 1>&2")
  system("git checkout pr-#{id} 1>&2")
  system("git config --add pullrequest.url #{pr['url']} 1>&2")
  system("git config --add pullrequest.id #{pr['number']} 1>&2")
end

puts JSON.generate(version:  { ref: ref, pr: id.to_s },
                   metadata: [{ name: 'url', value: pr['url'] }])
