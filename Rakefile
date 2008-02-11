require 'rake'
require 'rake/rdoctask'

desc 'Default: create rdoc.'
task :default => :rdoc

desc 'Generate documentation for the scaffolding_extensions plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Scaffolding Extensions'
  %w'--line-numbers --inline-source -a README lib'.each{|x| rdoc.options << x}
end
