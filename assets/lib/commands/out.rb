#!/usr/bin/env ruby

require 'json'
require_relative 'base'
require_relative '../repository'
require_relative '../status'

module Commands
  class Out < Commands::Base
    attr_reader :destination

    def initialize(destination:, input: Input.instance)
      @destination = destination

      super(input: input)
    end

    def output
      check_defaults!
      path = File.join(destination, params['path'])
      raise %(`path` "#{params['path']}" does not exist) unless File.exist?(path)

      if params.comment
        comment_path = File.join(destination, params.comment)
        raise %(`comment` "#{params.comment}" does not exist) unless File.exist?(comment_path)
      end

      if params.merge.commit_msg
        commit_path = File.join(destination, params.merge.commit_msg)
        raise %(`merge.commit_msg` "#{params.merge.commit_msg}" does not exist) unless File.exist?(commit_path)
      end

      id  = Dir.chdir(path) { `git config --get pullrequest.id`.chomp }
      sha = Dir.chdir(path) { `git rev-parse HEAD`.chomp }

      repo = Repository.new(name: input.source.repo)

      metadata = [{ 'name' => 'status', 'value' => params['status'] }]
      if id.empty?
        version = { 'ref' => sha }
      elsif id == 'new'
        title = Dir.chdir(path) { `git config --get pullrequest.title`.chomp }
        title = "Concourse CI Pull Request" if title.blank?
        body = Dir.chdir(path) { `git config --get pullrequest.body`.chomp }
        merge_into = Dir.chdir(path) { `git config --get pullrequest.mergeinto`.chomp }
        merge_into = "master" if merge_into.blank?
        branch = Dir.chdir(path) { `git symbolic-ref --short HEAD`.chomp }

        pr_dict = Octokit.create_pull_request(input.source.repo, merge_into, branch, title, body)
        pr = PullRequest.new(pr: pr_dict)
        metadata << { 'name' => 'url', 'value' => pr.url }
        id = pr.id.to_s
        version = { 'pr' => id, 'ref' => sha }
      else
        pr = PullRequest.from_github(repo: repo, id: id)
        metadata << { 'name' => 'url', 'value' => pr.url }
        version = { 'pr' => id, 'ref' => sha }
      end

      atc_url = input.source.base_url || ENV['ATC_EXTERNAL_URL']
      contextes = params.context || ['status']
      contextes = [contextes] unless contextes.is_a?(Array)

      contextes.each do |context|
        Status.new(
          state: params.status,
          atc_url: atc_url,
          sha: sha,
          repo: repo,
          context: whitelist(context: context)
        ).create!
      end

      if params.comment
        comment_path = File.join(destination, params.comment)
        comment = File.read(comment_path, encoding: Encoding::UTF_8)
        Octokit.add_comment(input.source.repo, id, comment)
        metadata << { 'name' => 'comment', 'value' => comment }
      end

      if params.merge.method
        commit_msg = if params.merge.commit_msg
                       commit_path = File.join(destination, params.merge.commit_msg)
                       File.read(commit_path, encoding: Encoding::UTF_8)
                     else
                       ''
        end
        Octokit.merge_pull_request(input.source.repo, id, commit_msg, merge_method: params.merge.method, accept: 'application/vnd.github.polaris-preview+json')
        metadata << { 'name' => 'merge', 'value' => params.merge.method }
        metadata << { 'name' => 'merge_commit_msg', 'value' => commit_msg }
      end

      {
        'version' => version,
        'metadata' => metadata
      }
    end

    private

    def whitelist(context:)
      %w[BUILD_ID BUILD_NAME BUILD_JOB_NAME BUILD_PIPELINE_NAME BUILD_TEAM_NAME ATC_EXTERNAL_URL].each do |name|
        context.gsub!("$#{name}", ENV[name] || '')
      end
      context
    end

    def params
      input.params
    end

    def check_defaults!
      raise %(`status` "#{params.status}" is not supported -- only success, failure, error, or pending) unless %w[success failure error pending].include?(params.status)
      raise %(`merge.method` "#{params.merge.method}" is not supported -- only merge, squash, or rebase) if params.merge.method && !%w[merge squash rebase].include?(params.merge.method)
      raise '`path` required in `params`' unless params.path
    end
  end
end

if $PROGRAM_NAME == __FILE__
  destination = ARGV.shift
  command = Commands::Out.new(destination: destination)
  puts JSON.generate(command.output)
end
