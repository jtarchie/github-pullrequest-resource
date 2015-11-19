#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'octokit'
require_relative 'common'

repo = Repository.new(name: input['source']['repo'])

input['version'] ||= {}

next_pull_request = repo.next_pull_request(id: input['version']['pr'], sha: input['version']['ref'])
if next_pull_request
  json!([next_pull_request.as_json])
else
  json!([])
end
