# frozen_string_literal: true

require_relative '../../assets/lib/filters/mergeable'
require_relative '../../assets/lib/pull_request'
require_relative '../../assets/lib/input'
require 'webmock/rspec'

describe Filters::Mergeable do
  let(:ignore_pr) do
    PullRequest.new(pr: { 'number' => 1, 'head' => { 'sha' => 'abc' }, 'mergeable' => false })
  end

  let(:pr) do
    PullRequest.new(pr: { 'number' => 2, 'head' => { 'sha' => 'def' }, 'mergeable' => true })
  end

  let(:pull_requests) { [ignore_pr, pr] }

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  context 'when mergeable requirement is disabled' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end

    it 'does not filter when explictly disabled' do
      payload = { 'source' => { 'repo' => 'user/repo', 'only_mergeable' => false } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when the mergeable filtering is enabled' do
    before do
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/1}, 'mergeable' => false)
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/2}, 'mergeable' => true)
    end

    it 'only returns PRs with that are mergeable' do
      payload = { 'source' => { 'repo' => 'user/repo', 'only_mergeable' => true } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end
end
