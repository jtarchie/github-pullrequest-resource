# frozen_string_literal: true

require_relative '../../assets/lib/filters/path'
require_relative '../../assets/lib/pull_request'
require 'webmock/rspec'

describe Filters::Path do
  let(:ignore_pr) do
    PullRequest.new(pr: { 'number' => 1 })
  end

  let(:pr) do
    PullRequest.new(pr: { 'number' => 2 })
  end

  let(:pull_requests) { [ignore_pr, pr] }

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  context 'when paths are not specified' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when paths are specified' do
    before do
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/1/files}, [{ 'filename' => 'test.cpp' }])
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/2/files}, [{ 'filename' => 'README.md' }])
    end

    context 'that is an ignore path' do
      it 'filters out PRs that match that path' do
        payload = { 'source' => { 'repo' => 'user/repo', 'ignore_paths' => ['README.md'] } }
        filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

        expect(filter.pull_requests).to eq [ignore_pr]
      end
    end

    context 'that is a path' do
      it 'only return PRs that match that path' do
        payload = { 'source' => { 'repo' => 'user/repo', 'paths' => ['README.md'] } }
        filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

        expect(filter.pull_requests).to eq [pr]
      end
    end
  end
end
