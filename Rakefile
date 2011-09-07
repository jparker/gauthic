require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new
task :default => :spec

task :specs => :spec

desc 'Start IRB with environment preloaded'
task :console do
  $stderr.puts "DEPRECATION WARNING: console task is obsolete: use 'bundle console' instead"
  exec 'bundle', 'console'
end
