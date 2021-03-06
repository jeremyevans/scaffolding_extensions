spec = Gem::Specification.new do |s|
  s.name = "scaffolding_extensions"
  s.version = '1.6.1'
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.platform = Gem::Platform::RUBY
  s.summary = "Administrative database front-end for multiple web-frameworks and ORMs"
  s.files = %w'MIT-LICENSE README' + Dir['{lib,doc,contrib,scaffolds}/**/*']
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.required_ruby_version = ">= 1.8.6"
  s.rdoc_options = %w'--inline-source --line-numbers README MIT-LICENSE lib' + Dir['doc/*.txt']
  s.homepage = 'http://scaf-ext.jeremyevans.net/'
end
