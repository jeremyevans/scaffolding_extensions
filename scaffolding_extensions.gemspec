spec = Gem::Specification.new do |s|
  s.name = "scaffolding_extensions"
  s.version = '1.3.6'
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.platform = Gem::Platform::RUBY
  s.summary = "Administrative database front-end for multiple web-frameworks and ORMs"
  s.files = %w'LICENSE README' + Dir['{lib,doc,contrib,scaffolds}/**/*']
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.rdoc_options = %w'--inline-source --line-numbers README LICENSE lib' + Dir['doc/*.txt']
  s.rubyforge_project = 'scaffolding-ext'
  s.homepage = 'http://scaffolding-ext.rubyforge.org/'
end
