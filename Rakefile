require 'rspec/core/rake_task'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'cucumber'
require 'cucumber/rake/task'

RSpec::Core::RakeTask.new(:spec)

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features'
end

RuboCop::RakeTask.new(:rubocop)

task default: [:rubocop, :spec, :features]
