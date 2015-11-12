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

  context 'when acquiring a pull request' do
    it 'sets into pending mode' do
      out(params: {}, source: {})
    end
  end

  context 'when the pull request is being release' do
    context 'and the build passed' do
      it 'sets into success mode' do
        out(params: {}, source: {})
      end
    end

    context 'and the build failed' do
      it 'sets into failure mode' do
        out(params: {}, source: {})
      end
    end
  end
end
