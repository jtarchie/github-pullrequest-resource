require_relative '../../assets/lib/filters/state'
require_relative '../../assets/lib/pull_request'
require_relative '../../assets/lib/input'
require 'webmock/rspec'

describe Filters::State do
  let(:ignore_pr) do
    PullRequest.new(pr: { 'number' => 1, 'state' => 'open' })
  end

  let(:pr) do
    PullRequest.new(pr: { 'number' => 2, 'state' => 'closed' })
  end

  let(:pull_requests) { [ignore_pr, pr] }

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  context 'when no state is specified' do
    it 'does not filter' do
      payload = { 'source' => { 'repo' => 'user/repo' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq pull_requests
    end
  end

  context 'when the state for filtering is provided' do
    it 'only returns PRs with that label' do
      payload = { 'source' => { 'repo' => 'user/repo', 'state' => 'closed' } }
      filter = described_class.new(pull_requests: pull_requests, input: Input.instance(payload: payload))

      expect(filter.pull_requests).to eq [pr]
    end
  end
end
