require 'rake'
require 'rake/clean'
require 'rake/rdoctask'

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += ["--quiet", "--line-numbers", "--inline-source"]
  rdoc.main = "README"
  rdoc.title = "Scaffolding Extensions: Administrative database front-end for multiple web-frameworks and ORMs"
  rdoc.rdoc_files.add ["README", "LICENSE", "lib/**/*.rb", "doc/*.txt"]
end

desc "Update docs and upload to rubyforge.org"
task :doc_rforge => [:rdoc]
task :doc_rforge do
  sh %{chmod -R g+w rdoc/*}
  sh %{scp -rp rdoc/* rubyforge.org:/var/www/gforge-projects/scaffolding-ext}
end

desc "Package Scaffolding Extensions"
task :package do
  sh %{gem build scaffolding_extensions.gemspec}
end
