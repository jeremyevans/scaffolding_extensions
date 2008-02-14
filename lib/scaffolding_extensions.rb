require 'set'

# This is the base module for the plugin.  It has some constants that can be
# changed:
#
# * TEMPLATE_DIR - the directory with the scaffold templates
# * DEFAULT_METHODS - the default methods added by the scaffolding
#
# If you include the contents of auto_complete.css in your stylesheet, set
# "auto_complete_skip_style = true", so the stylesheet isn't added for every
# autocompleting text box.
#
# Scaffolding Extensions attempts to determine which framework/ORM you are
# using and load the support for it (if it is supported).
module ScaffoldingExtensions
  AUTO_COMPLETE_CSS = <<-END
    <style type='text/css'>
      div.auto_complete {
        width: 350px;
        background: #fff;
      }
      div.auto_complete ul {
        border:1px solid #888;
        margin:0;
        padding:0;
        width:100%;
        list-style-type:none;
      }
      div.auto_complete ul li {
        margin:0;
        padding:3px;
      }
      div.auto_complete ul li.selected { 
        background-color: #ffb; 
      }
      div.auto_complete ul strong.highlight { 
        color: #800; 
        margin:0;
        padding:0;
      }
    </style>
  END
  ROOT = File.dirname(File.dirname(__FILE__))
  TEMPLATE_DIR = File.join(ROOT, "scaffolds")
  DEFAULT_METHODS = [:manage, :show, :delete, :edit, :new, :search, :merge, :browse]
  
  @auto_complete_skip_style = false
    
  class << self
    attr_accessor :auto_complete_skip_style
    attr_writer :all_models, :model_files

    # The stylesheet for the autocompleting text box, or the empty string
    # if auto_complete_skip_style is true.
    def auto_complete_css
      auto_complete_skip_style ? '' : AUTO_COMPLETE_CSS
    end
  end
end

require 'scaffolding_extensions/controller'
require 'scaffolding_extensions/meta_controller'
require 'scaffolding_extensions/helper'
require 'scaffolding_extensions/prototype_helper'

require 'scaffolding_extensions/controller/action_controller' if defined? ActionController::Base
require 'scaffolding_extensions/controller/ramaze' if defined? Ramaze::Controller

require 'scaffolding_extensions/model/active_record' if defined? ActiveRecord::Base
  
