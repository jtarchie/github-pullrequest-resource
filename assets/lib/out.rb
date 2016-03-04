#!/usr/bin/env ruby
# encoding: utf-8

destination = ARGV.shift

require 'rubygems'
require 'json'
require 'octokit'
require_relative 'common'

raise %(`status` "#{input['params']['status']}" is not supported -- only success, failure, error, or pending) unless %w(success failure error pending).include?(input['params']['status'])
raise '`path` required in `params`' unless input['params'].key?('path')

path = File.join(destination, input['params']['path'])
raise %(`path` "#{input['params']['path']}" does not exist) unless File.exist?(path)

id  = Dir.chdir(path) { `git config --get pullrequest.id`.chomp }
sha = Dir.chdir(path) { `git rev-parse HEAD`.chomp }

repo = Repository.new(name: input['source']['repo'])

metadata = [{ name: 'status', value: input['params']['status'] }]
if id.empty?
  version = { ref: sha }
else
  pr = repo.pull_request(id: id)
  metadata << { name: 'url', value: pr.url }
  version = { pr: id, ref: sha }
end

atc_url = input['source']['base_url'] || ENV['ATC_EXTERNAL_URL']
context = input['params']['context'] || 'concourse-ci'

Status.new(
  state: input['params']['status'],
  atc_url: atc_url,
  sha: sha,
  repo: repo,
  context: context
).create!

json!(version: version, metadata: metadata)
