unless defined?(ScaffoldingExtensions)
  $:.unshift('../lib')
  require 'scaffolding_extensions'
end

ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:search_limit] = 1
ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:browse_limit] = 1
