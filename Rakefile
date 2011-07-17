require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new
task :default => :spec

task :specs => :spec

desc 'Start IRB with environment preloaded'
task :console do
  exec 'irb', "-I#{File.join(File.dirname(__FILE__), 'lib')}", '-rgauthic'
end
