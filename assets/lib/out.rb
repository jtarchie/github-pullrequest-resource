#!/usr/bin/env ruby

destination = ARGV.shift

require 'rubygems'
require 'json'
require 'octokit'
require_relative 'common'

fail %(`status` "#{input['params']['status']}" is not supported -- only success, failure, error, or pending) unless %w(success failure error pending).include?(input['params']['status'])
fail '`path` required in `params`' unless input['params'].key?('path')

path = File.join(destination, input['params']['path'])
fail %(`path` "#{input['params']['path']}" does not exist) unless File.exist?(path)

id = Dir.chdir(path) do
  `git config --get pullrequest.id`.chomp
end

fail 'could not get pullrequest `id` from repository' unless id

repo = Repository.new(name: input['source']['repo'])
pr   = repo.pull_request(id: id)

pr.status!(state: input['params']['status'], atc_url: input['source']['base_url'])

json!(version: pr.as_json,
      metadata: [
        { name: 'url', value: pr.url },
        { name: 'status', value: input['params']['status'] }
      ])
