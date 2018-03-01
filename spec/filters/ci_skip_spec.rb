# frozen_string_literal: true

require_relative '../../assets/lib/filters/ci_skip'
require_relative '../../assets/lib/pull_request'
require_relative '../../assets/lib/input'
require 'webmock/rspec'

describe Filters::CISkip do
  let(:ignore_pr) do
    PullRequest.new(pr: { 'number' => 1, 'head' => { 'sha' => 'abc' } })
  end

  let(:pr) do
    PullRequest.new(pr: { 'number' => 2, 'head' => { 'sha' => 'def' } })
  end

  let(:pull_requests) { [ignore_pr, pr] }

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  context 'when ci skip is disabled' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end

    it 'does not filter when explictly disabled' do
      payload = { 'source' => { 'repo' => 'user/repo', 'ci_skip' => false } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when the ci skip filterings is enabled' do
    before do
      stub_json(%r{https://api.github.com/repos/user/repo/commits/abc}, 'commit' => { 'message' => '[ci skip]' })
      stub_json(%r{https://api.github.com/repos/user/repo/commits/def}, 'commit' => { 'message' => 'do not skip' })
    end

    it 'only returns PRs with that label' do
      payload = { 'source' => { 'repo' => 'user/repo', 'ci_skip' => true } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end
end
