require_relative 'support/proxy'
require_relative 'support/cli'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.include CliIntegration
end

def with_resource
  tmp_dir = Dir.mktmpdir
  FileUtils.cp_r(dest_dir, File.join(tmp_dir, 'resource'))
  yield(tmp_dir)
end

def must_stub_query_params
  around do |example|
    old_strip_params = Billy.config.strip_query_params
    Billy.config.strip_query_params = false
    example.run
    Billy.config.strip_query_params = old_strip_params
  end
end
