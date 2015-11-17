require 'spec_helper'

describe 'out' do
  let(:proxy) { Billy::Proxy.new }
  let(:dest_dir) { Dir.mktmpdir }

  before { proxy.start }
  after  { proxy.reset }

  def out(payload = {})
    path = ['./assets/out', '/opt/resource/out'].find { |p| File.exist? p }
    payload[:source] = { repo: 'jtarchie/test' }

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dest_dir}`
    JSON.parse(output)
  end

  before do
    proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
      .and_return(json: [{
      url: 'http://example.com',
      id: 1,
      head: { sha: 'abcdef' }
    }])
    proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
      .and_return(json: [])
  end

  context 'when acquiring a pull request' do
    it 'sets into pending mode' do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef', method: :post)

      output = out(params: { status: 'pending' }, source: { repo: 'jtarchie/test' })
      expect(output).to eq('version'  => { 'ref' => 'abcdef', 'pr' => '1' },
                           'metadata' => { 'url' => 'http://example.com', 'status' => 'pending' })
    end
  end

  context 'when the pull request is being release' do
    context 'and the build passed' do
      it 'sets into success mode' do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef', method: :post)

        output = out(params: { status: 'success' }, source: { repo: 'jtarchie/test' })
        expect(output).to eq('version'  => { 'ref' => 'abcdef', 'pr' => '1' },
                             'metadata' => { 'url' => 'http://example.com', 'status' => 'success' })
      end
    end

    context 'and the build failed' do
      it 'sets into failure mode' do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef', method: :post)

        output = out(params: { status: 'failure' }, source: { repo: 'jtarchie/test' })
        expect(output).to eq('version'  => { 'ref' => 'abcdef', 'pr' => '1' },
                             'metadata' => { 'url' => 'http://example.com', 'status' => 'failure' })
      end
    end
  end
end
