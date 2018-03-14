# frozen_string_literal: true

require_relative '../../assets/lib/filters/approval'
require_relative '../../assets/lib/pull_request'
require_relative '../../assets/lib/input'
require 'webmock/rspec'

describe Filters::Approval do
  let(:ignore_pr) do
    PullRequest.new(pr: { 'number' => 1, 'head' => { 'sha' => 'abc' }, 'author_association' => 'NONE',
                          'base' => { 'repo' => { 'full_name' => 'user/repo', 'permissions' => { 'push' => true } } } })
  end

  let(:pr) do
    PullRequest.new(pr: { 'number' => 2, 'head' => { 'sha' => 'def' }, 'author_association' => 'OWNER',
                          'base' => { 'repo' => { 'full_name' => 'user/repo', 'permissions' => { 'push' => true } } } })
  end

  let(:pull_requests) { [ignore_pr, pr] }

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  context 'when all approval requirements are disabled' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end

    it 'does not filter when explictly disabled' do
      payload = { 'source' => { 'repo' => 'user/repo', 'require_manual_approval' => false, 'require_review_approval' => false, 'authorship_restriction' => false } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when owner filtering is enabled' do
    it 'only returns PRs that are repo-owners' do
      payload = { 'source' => { 'repo' => 'user/repo', 'require_manual_approval' => false, 'require_review_approval' => false, 'authorship_restriction' => true } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end

  context 'when approval filtering is enabled' do
    before do
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/1/reviews}, [{ 'state' => 'CHANGES_REQUESTED' }])
      stub_json(%r{https://api.github.com/repos/user/repo/pulls/2/reviews}, [{ 'state' => 'APPROVED' }])
    end

    it 'only returns PRs that are approved' do
      payload = { 'source' => { 'repo' => 'user/repo', 'require_manual_approval' => false, 'require_review_approval' => true, 'authorship_restriction' => false } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end
end
