#!/usr/bin/env ruby

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

system("git clone --recursive --depth 1 #{uri} #{destination} 1>&2")
Dir.chdir(destination) do
  system("git fetch -q origin pull/#{id}/head:pr-#{id}")
  system("git checkout pr-#{id}")
  system("git config --add pullrequest.url #{pr['url']}")
  system("git config --add pullrequest.id #{pr['number']}")
end

puts JSON.generate(version:  { ref: ref, pr: id.to_s },
                   metadata: [{ name: 'url', value: pr['url'] }])
