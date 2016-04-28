#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'json'
require_relative 'common'
require 'octokit'

repo = Repository.new(name: input['source']['repo'])

input['version'] ||= {}

next_pull_request = repo.next_pull_request(id: input['version']['pr'], sha: input['version']['ref'])
if next_pull_request
  json!([next_pull_request.as_json])
else
  json!([])
end
