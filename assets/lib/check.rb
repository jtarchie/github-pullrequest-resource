#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require_relative 'common'
require 'octokit'

repo = Repository.new(name: input['source']['repo'])

input['version'] ||= {}

if input['source']['every']
  json!(repo.pull_requests.map(&:as_json).reverse)
else
  next_pull_request = repo.next_pull_request(
    id: input['version']['pr'],
    sha: input['version']['ref'],
    base: input['source']['base']
  )
  if next_pull_request
    json!([next_pull_request.as_json])
  else
    json!([])
  end
end
