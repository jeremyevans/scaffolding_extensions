require 'rake'

RDOC_OPTS = ["--line-numbers", "--inline-source", '--main', 'README']

begin
  # Sequel uses hanna-nouveau for the website RDoc.
  # Due to bugs in older versions of RDoc, and the
  # fact that hanna-nouveau does not support RDoc 4,
  # a specific version of rdoc is required.
  gem 'rdoc', '= 3.12.2'
  gem 'hanna-nouveau'
  RDOC_OPTS.concat(['-f', 'hanna'])
  true
rescue Gem::LoadError
  false
end

rdoc_task_class = begin
  require "rdoc/task"
  RDoc::Task
rescue LoadError
  begin
    require "rake/rdoctask"
    Rake::RDocTask
  rescue LoadError, StandardError
  end
end

if rdoc_task_class
  rdoc_task_class.new do |rdoc|
    rdoc.rdoc_dir = "rdoc"
    rdoc.options += RDOC_OPTS
    rdoc.main = "README"
    rdoc.title = "Scaffolding Extensions: Administrative database front-end for multiple web-frameworks and ORMs"
    rdoc.rdoc_files.add ["README", "MIT-LICENSE", "lib/**/*.rb", "doc/*.txt"]
  end
end

desc "Package Scaffolding Extensions"
task :package do
  sh %{gem build scaffolding_extensions.gemspec}
end
