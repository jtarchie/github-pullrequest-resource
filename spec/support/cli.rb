require 'open3'

module CliIntegration
  def check(payload)
    path = ['./assets/check', '/opt/resource/check'].find { |p| File.exist? p }
    payload[:source][:no_ssl_verify] = true

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path}`
    JSON.parse(output)
  end

  def get(payload = {})
    path = ['./assets/in', '/opt/resource/in'].find { |p| File.exist? p }
    payload[:source][:no_ssl_verify] = true

    output, error, = with_resource do |_dir|
      Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dest_dir}")
    end

    response = begin
                 JSON.parse(output)
               rescue
                 nil
               end
    [response, error]
  end

  def put(payload = {})
    path = ['./assets/out', '/opt/resource/out'].find { |p| File.exist? p }
    payload[:source][:no_ssl_verify] = true

    output, error, = with_resource do |dir|
      Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dir}")
    end

    response = begin
                 JSON.parse(output)
               rescue
                 nil
               end
    [response, error]
  end
end
