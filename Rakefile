task :build do
  system('docker build -t jtarchie/pr .')
end

task :test => :build do
  system('docker build -f Dockerfile.test -t jtarchie/pr:test .')
end

task default: :build
