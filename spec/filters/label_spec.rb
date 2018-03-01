# frozen_string_literal: true

require_relative '../../assets/lib/filters/label'
require_relative '../../assets/lib/pull_request'
require_relative '../../assets/lib/input'
require 'webmock/rspec'

describe Filters::Label do
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

  context 'when no label is specified' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when the label for filtering is provided' do
    before do
      stub_json(%r{https://api.github.com/repos/user/repo/issues/1}, 'labels' => [{ 'name' => 'feature' }])
      stub_json(%r{https://api.github.com/repos/user/repo/issues/2}, 'labels' => [{ 'name' => 'bug' }])
    end

    it 'only returns PRs with that label' do
      payload = { 'source' => { 'repo' => 'user/repo', 'label' => 'bug' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end
end
