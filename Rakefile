# encoding: utf-8
task :build do
  system('docker build -t jtarchie/pr .')
end

task test: :build do
  system('docker build -f Dockerfile.test -t jtarchie/pr:test .')
end

task :deploy do
  current_tag = `git tag -l`.split(/\n/).map{|v|v=~/v(\d+)/;$1.to_i}.sort.last
  next_tag    = current_tag + 1
  puts "Deploying tag #{next_tag}"
  system("git tag v#{next_tag}")
  system("docker tag jtarchie/pr:latest jtarchie/pr:#{next_tag}")
  system('docker push jtarchie/pr && git push --tag')
end

task default: :build
