# Scaffolding Extensions
module ActiveRecord # :nodoc:
  # Modifying class variables allows you to set various defaults for scaffolding. 
  # Note that if multiple subclasses each modify the class variables, chaos will ensue.
  # Class variables have cattr_accessor so that you can set them in environment.rb, such as:
  # ActiveRecord::Base.scaffold_convert_text_to_string = true
  #
  # Available class variables:
  # - scaffold_convert_text_to_string: If true, by default, use input type text instead of textarea 
  #   for fields of type text (default: false)
  # - scaffold_table_classes: Set the default table classes for different scaffolded HTML tables
  #   (default: {:form=>'formtable', :list=>'sortable', :show=>'sortable'})
  # - scaffold_column_types: Override the default column type for a given attribute 
  #   (default: {'password'=>:password})
  # - scaffold_column_options_hash: Override the default column options for a given attribute (default: {})
  # - scaffold_association_list_class: Override the html class for the association list in the edit view
  #   (default: '')
  # - scaffold_browse_default_records_per_page - The default number of records per page to show in the
  #   browse scaffold (default: 10)
  # - scaffold_search_results_default_limit - The default limit on scaffolded search results 
  #   (default: nil # no limit)
  # - scaffold_auto_complete_default_options: Hash containing the default options to use for the scaffold
  #   autocompleter (default: {:enable=>false, :sql_name=>'LOWER(name)', :text_field_options=>{:size=>50},
  #   :format_string=>:substring, :search_operator=>'LIKE', :results_limit=>10, :phrase_modifier=>:downcase,
  #   :skip_style=>false})
  #
  # Modifying instance variables in each class affects scaffolding for that class only (always defaults to nil).
  # Available instance variables:
  #
  # - scaffold_fields: List of field names to include in the scaffolded forms.
  #   Values in the list should be either actual fields names, or names of belongs_to
  #   associations (in which case select boxes will be used in the scaffolded forms).
  #   Uses content_columns + belongs_to associations if not specified.
  #   (example: %w'name number rating')
  # - scaffold_select_order: SQL fragment string setting the order in which scaffolded records are shown
  #   (example: 'firstname, lastname')
  # - scaffold_include: Any classes that should include by default when displaying the
  #   scaffold name.  Eager loading is used so that N+1 queries aren't used for displaying N
  #   records, assuming that associated records used in scaffold_name are included in this.
  #   (example: [:artist, :album])
  # - scaffold_associations: List of associations to display on the scaffolded edit page for the object.
  #   Uses all associations if not specified (example: %w'artist albums')
  # - scaffold_associations_path: String path to the template to use to render the associations
  #   for the edit page.  Uses the controller's scaffold path if not specified.
  #   (example: "#{RAILS_ROOT}/lib/model_associations.rhtml")
  # - scaffold_browse_records_per_page - The number of records per page to show in the
  #   browse scaffold.  Uses scaffold_browse_default_records_per_page if not specified (example: 25)
  # - scaffold_search_results_limit - The limit on the number of records in the scaffolded search
  #   results page (example: 25)
  # - scaffold_auto_complete_options - Hash merged with the auto complete default options to set
  #   the auto complete options for the model.  If the auto complete default options are set
  #   with :enable=>false, setting this variable turns on autocompleting.  If the auto complete
  #   default options are set with :enable=>true, autocompleting can be turned off for this
  #   model with {:enable=>false}.  (example: {})
  #
  # scaffold_table_classes, scaffold_column_types, and scaffold_column_options_hash can also
  # be specified as instance variables, in which case they will override the class variable
  # defaults.
  class Base
    @@scaffold_convert_text_to_string = false
    @@scaffold_table_classes = {:form=>'formtable', :list=>'sortable', :show=>'sortable'}
    @@scaffold_column_types = {'password'=>:password}
    @@scaffold_column_options_hash = {}
    @@scaffold_association_list_class = ''
    @@scaffold_browse_default_records_per_page = 10
    @@scaffold_search_results_default_limit = nil
    @@scaffold_auto_complete_default_options = {:enable=>false, :sql_name=>'LOWER(name)',
      :text_field_options=>{:size=>50}, :format_string=>:substring, :search_operator=>'LIKE',
      :results_limit=>10, :phrase_modifier=>:downcase, :skip_style=>false}
    cattr_accessor :scaffold_convert_text_to_string, :scaffold_table_classes, :scaffold_column_types, :scaffold_column_options_hash, :scaffold_association_list_class, :scaffold_auto_complete_default_options, :scaffold_browse_default_records_per_page, :scaffold_search_results_default_limit
    
    class << self
      attr_accessor :scaffold_select_order, :scaffold_include, :scaffold_associations_path
      
      # Checks all files in the models directory to return strings for all models
      # that are a subclass of the current class
      def all_models
        Dir["#{RAILS_ROOT}/app/models/*.rb"].collect{|file|File.basename(file).sub(/\.rb$/, '')}.sort.reject{|model| (! model.camelize.constantize.ancestors.include?(self)) rescue true}
      end
      
      # Merges the record with id from into the record with id to.  Updates all 
      # associated records for the record with id from to be assocatiated with
      # the record with id to instead, and then deletes the record with id from.
      #
      # Returns false if the ids given are the same.
      def merge_records(from, to)
        return false if from == to
        transaction do
          reflect_on_all_associations.each{|reflection| reflection_merge(reflection, from, to)}
          destroy(from)
        end
        true
      end
      
      # Updates associated records for a given reflection and from record to point to the
      # to record
      def reflection_merge(reflection, from, to)
        foreign_key = reflection.options[:foreign_key] || table_name.classify.foreign_key
        sql = case reflection.macro
          when :has_one, :has_many
            "UPDATE #{reflection.klass.table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n" 
          when :has_and_belongs_to_many
            join_table = reflection.options[:join_table] || ( table_name < reflection.klass.table_name ? '#{table_name}_#{reflection.klass.table_name}' : '#{reflection.klass.table_name}_#{table_name}')
            "UPDATE #{join_table} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n" 
          else return
        end
        connection.update(sql)
      end
      
      # List of strings for associations to display on the scaffolded edit page
      def scaffold_associations
        @scaffold_associations ||= reflect_on_all_associations.collect{|r|r.name.to_s}.sort
      end
      
      # Returns the list of fields to display on the scaffolded forms. Defaults
      # to displaying all usually scaffolded columns with the addition of belongs
      # to associations.
      def scaffold_fields
        return @scaffold_fields if @scaffold_fields
        @scaffold_fields = columns.reject{|c| c.primary || c.name =~ /_count$/ || c.name == inheritance_column }.collect{|c| c.name}
        reflect_on_all_associations.each do |reflection|
          next unless reflection.macro == :belongs_to
          @scaffold_fields.delete((reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key).to_s)
          @scaffold_fields.push(reflection.name.to_s)
        end
        @scaffold_fields.sort!
        @scaffold_fields
      end
      
      # Returns the scaffolded table class for a given scaffold type.
      def scaffold_table_class(type)
        @scaffold_table_classes ||= scaffold_table_classes
        @scaffold_table_classes[type]
      end
      
      # Returns the column type for the given scaffolded column name.  First checks to see
      # if a value has been overriden using a class or instance variable, otherwise uses
      # the default column type.
      def scaffold_column_type(column_name)
        @scaffold_column_types ||= scaffold_column_types
        if @scaffold_column_types[column_name]
          @scaffold_column_types[column_name]
        elsif columns_hash.include?(column_name)
          type = columns_hash[column_name].type
          (scaffold_convert_text_to_string and type == :text) ? :string : type
        end
      end
      
      # Returns any special options for a given attribute
      def scaffold_column_options(column_name)
        @scaffold_column_options_hash ||= scaffold_column_options_hash
        @scaffold_column_options_hash[column_name]
      end
      
      # The number of records to show on each page when using the browse scaffold
      def scaffold_browse_records_per_page
        @scaffold_browse_records_per_page ||= scaffold_browse_default_records_per_page
      end
      
      # The maximum number of results to show on the scaffolded search results page
      def scaffold_search_results_limit
        @scaffold_search_results_limit ||= scaffold_search_results_default_limit
      end
      
      # If the auto complete options have been setup, return them.  Otherwise,
      # create the auto complete options using the defaults and the existing
      # class instance variable.
      def scaffold_auto_complete_options
        return @scaffold_auto_complete_options if @scaffold_auto_complete_options && @scaffold_auto_complete_options[:setup]
        @scaffold_auto_complete_options = @scaffold_auto_complete_options.nil? ? {} : {:enable=>true}.merge(@scaffold_auto_complete_options)
        @scaffold_auto_complete_options = scaffold_auto_complete_default_options.merge(@scaffold_auto_complete_options)
        @scaffold_auto_complete_options[:setup] = true
        @scaffold_auto_complete_options
      end
      
      # Whether this class should use an autocompleting text box instead of a select
      # box for choosing items.
      def scaffold_use_auto_complete
        scaffold_auto_complete_options[:enable]
      end
      
      # SQL fragment (usually column name) that is used when scaffold autocompleting is turned on.
      def scaffold_name_sql
        scaffold_auto_complete_options[:sql_name]
      end
      
      # Options for the scaffold autocompleting text field
      def scaffold_auto_complete_text_field_options
        scaffold_auto_complete_options[:text_field_options]
      end
      
      def scaffold_auto_complete_skip_style
        scaffold_auto_complete_options[:skip_style]
      end
      
      # Format string used with the phrase to choose the type of search.  Can be
      # a user defined format string or one of these special symbols:
      # - :substring - Phase matches any substring of scaffold_name_sql
      # - :starting - Phrase matches the start of scaffold_name_sql
      # - :ending - Phrase matches the end of scaffold_name_sql
      # - :exact - Phrase matches scaffold_name_sql exactly
      def scaffold_auto_complete_search_format_string
        {:substring=>'%%%s%%', :starting=>'%s%%', :ending=>'%%%s', :exact=>'%s'}[scaffold_auto_complete_options[:format_string]] || scaffold_auto_complete_options[:format_string]
      end
      
      # Search operator for matching scaffold_name_sql to format_string % phrase,
      # usally 'LIKE', but might be 'ILIKE' on some databases.
      def scaffold_auto_complete_search_operator
        scaffold_auto_complete_options[:search_operator]
      end
      
      # The number of results to return for the scaffolded autocomplete text box.
      def scaffold_auto_complete_results_limit
        scaffold_auto_complete_options[:results_limit]
      end
      
      # The conditions phrase (the sql code with ? place holders) used in the
      # scaffolded autocomplete find.
      def scaffold_auto_complete_conditions_phrase
        scaffold_auto_complete_options[:conditions_phrase] ||= "#{scaffold_name_sql} #{scaffold_auto_complete_search_operator} ?"
      end
      
      # A symbol for a string method to send to the submitted phrase.  Usually
      # :downcase to preform a case insensitive search, but may be :to_s for
      # a case sensitive search.
      def scaffold_auto_complete_phrase_modifier
        scaffold_auto_complete_options[:phrase_modifier]
      end
      
      # The conditions to use for the scaffolded autocomplete find.
      def scaffold_auto_complete_conditions(phrase)
        [scaffold_auto_complete_conditions_phrase, (scaffold_auto_complete_search_format_string % phrase.send(scaffold_auto_complete_phrase_modifier))]
      end
      
      # Return all records that match the given phrase (usually a substring of
      # the most important column).
      def scaffold_auto_complete_find(phrase, options = {})
        find_options = { :limit => scaffold_auto_complete_results_limit,
            :conditions => scaffold_auto_complete_conditions(phrase), 
            :order => scaffold_select_order,
            :include => scaffold_include}.merge(options)
        find(:all, find_options)
      end
    end
    
    # Merges the current record into the record given and returns the record given.
    # Returns false if the record isn't the same class as the current class or
    # if you try to merge a record into itself (which would be the same as deleting it).
    def merge_into(record)
      return false unless record.class == self.class && self.class.merge_records(self, id, record.id)
      record.reload
    end
    
    # The name given to the item that is used in various places in the scaffold.  For example,
    # it is used whenever the record is displayed in a select box.  Should be unique for each record.
    # Should be overridden by subclasses unless they have a unique attribute named 'name'.
    def scaffold_name
      self[:name] or id
    end
    
    # scaffold_name prefixed with id, used for scaffold autocompleting (a nice hack thanks 
    # to String#to_i)
    def scaffold_name_with_id
      "#{id} - #{scaffold_name}"
    end
  end
end

module ActionView # :nodoc:
  module Helpers # :nodoc:
    # Changes the default scaffolding of new/edit forms to handle associated
    # records, and uses a table to display the form.
    module ActiveRecordHelper
      # Uses a table to display the form widgets, so that everything lines up
      # nicely.  Handles associated records. Also allows for a different set
      # of fields to be specified instead of the default scaffold_fields.
      def all_input_tags(record, record_name, options)
        input_block = options[:input_block] || default_input_block
        rows = (options[:fields] || record.class.scaffold_fields).collect do |field|
          reflection = record.class.reflect_on_association(field.to_sym)
          if reflection
            input_block.call(record_name, reflection) 
          else
            input_block.call(record_name, record.column_for_attribute(field))
          end
        end
        "\n<table class='#{record.class.scaffold_table_class :form}'><tbody>\n#{rows.join}</tbody></table><br />"
      end
      
      # Wraps each widget and widget label in a table row
      def default_input_block
        Proc.new do |record, column| 
          if column.class.name =~ /Reflection/
            if column.macro == :belongs_to
              "<tr><td>#{column.name.to_s.humanize}:</td><td>#{association_select_tag(record, column.name)}</td></tr>\n"
            end
          else
            "<tr><td>#{column.human_name}:</td><td>#{input(record, column.name)}</td></tr>\n"
          end  
        end
      end
      
      # Returns a select box displaying the possible records that can be associated.
      # If scaffold autocompleting is turned on for the associated model, uses
      # an autocompleting text box.  Otherwise, creates a select box using
      # the associated model's scaffold_name and scaffold_select_order.
      def association_select_tag(record, association)
        reflection = record.camelize.constantize.reflect_on_association(association)
        foreign_key = reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key
        if reflection.klass.scaffold_use_auto_complete
          scaffold_text_field_with_auto_complete(record, foreign_key, reflection.klass.name.underscore)
        else
          items = reflection.klass.find(:all, :order => reflection.klass.scaffold_select_order, :conditions=>reflection.options[:conditions], :include=>reflection.klass.scaffold_include)
          items.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if reflection.klass.scaffold_include
          select(record, foreign_key, items.collect{|i| [i.scaffold_name, i.id]}, {:include_blank=>true})
        end
      end
    end
    
    # Methods used to implement scaffold autocompleting
    module JavaScriptMacrosHelper
      # Text field with autocompleting used for belongs_to associations of main object in scaffolded forms.
      def scaffold_text_field_with_auto_complete(object, method, associated_class, tag_options = {})
        klass = associated_class.to_s.camelize.constantize
        foreign_key = instance_variable_get("@#{object}").send(method)
        ((klass.scaffold_auto_complete_skip_style ? '' : auto_complete_stylesheet) +
        text_field(object, method, klass.scaffold_auto_complete_text_field_options.merge({:value=>(foreign_key ? klass.find(foreign_key).scaffold_name_with_id : '')}).merge(tag_options)) +
        content_tag("div", "", :id => "#{object}_#{method}_scaffold_auto_complete", :class => "auto_complete") +
        scaffold_auto_complete_field("#{object}_#{method}", { :url => { :action => "scaffold_auto_complete_for_#{associated_class}" } }))
      end
      
      # Text field with autocompleting for classes without an attached object.
      def scaffold_text_field_tag_with_auto_complete(id, klass, tag_options = {})
        ((klass.scaffold_auto_complete_skip_style ? '' : auto_complete_stylesheet) +
        text_field_tag(id, nil, klass.scaffold_auto_complete_text_field_options.merge(tag_options)) +
        content_tag("div", "", :id => "#{id}_scaffold_auto_complete", :class => "auto_complete") +
        scaffold_auto_complete_field(id, { :url => { :action => "scaffold_auto_complete_for_#{klass.name.underscore}"} }))
      end
      
      # Javascript code for setting up autocomplete for given field_id
      def scaffold_auto_complete_field(field_id, options = {})
        javascript_tag("var #{field_id}_auto_completer = new Ajax.Autocompleter('#{field_id}', '#{options[:update] || "#{field_id}_scaffold_auto_complete"}', '#{url_for(options[:url])}', {paramName:'id'})")
      end
      
      # Formats auto_complete_result using model's scaffold_name_with_id
      def scaffold_auto_complete_result(entries)
        return unless entries
        content_tag("ul", entries.map{|entry| content_tag("li", h(entry.scaffold_name_with_id))}.uniq)
      end
    end
    
    class InstanceTag
      # Gets the default options for the attribute and merges them with the given options.
      # Chooses an appropriate widget based on attribute's column type.
      def to_tag(options = {})
        options = (object.class.scaffold_column_options(@method_name) || {}).merge(options)
        case column_type
          when :string, :integer, :float
            to_input_field_tag("text", options)
          when :password
            to_input_field_tag("password", options)
          when :text
            to_text_area_tag(options)
          when :date
            to_date_select_tag(options)
          when :datetime
            to_datetime_select_tag(options)
          when :boolean
            to_boolean_select_tag(options)
        end
      end
      
      # Returns three valued select widget, for null, false, and true, with the appropriate
      # value selected
      def to_boolean_select_tag(options = {})
        options = options.stringify_keys
        add_default_name_and_id(options)
        "<select#{tag_options(options)}><option value=''#{selected(value.nil?)}>&nbsp;</option><option value='f'#{selected(value == false)}>False</option><option value='t'#{selected(value)}>True</option></select>"
      end
      
      # Returns XHTML compliant fragment for whether the value is selected or not
      def selected(value)
        value ? " selected='selected'" : '' 
      end
      
      # Allow overriding of the column type by asking the ActiveRecord for the appropriate column type.
      def column_type
        object.class.scaffold_column_type(@method_name)
      end
    end
  end
end

# Contains methods used by the scaffolded forms.
module ScaffoldHelper
  # Returns link if the controller will respond to the given action, otherwise returns the text itself.
  # If :action is not specified in the options, returns link.
  def link_to_or_text(name, options={}, html_options=nil, *parameters_for_method_reference)
    link_to_or_plain_text(name, name, options, html_options, *parameters_for_method_reference)
  end
  
  # Returns link if the controller will respond to the given action, otherwise returns "".
  # If :action is not specified in the options, returns link.
  def link_to_or_blank(name, options={}, html_options=nil, *parameters_for_method_reference)
    link_to_or_plain_text(name, '', options, html_options, *parameters_for_method_reference)
  end
  
  # Returns link if the controller will respond to the given action, otherwise returns plain.
  # If :action is not specified in the options, returns link.
  def link_to_or_plain_text(name, plain, options={}, html_options=nil, *parameters_for_method_reference)
    _controller = options[:controller] ? options[:controller].camelize.constantize : controller
    if options[:action]
      _controller.respond_to?(options[:action]) ? link_to(name, options, html_options, *parameters_for_method_reference) : plain
    else link_to(name, options, html_options, *parameters_for_method_reference)
    end
  end
  
  # Returns html fragment containing information on related models and objects.
  # The fragment will include links to scaffolded pages for the related items if the links would work.
  def association_links
    filename = (@scaffold_class.scaffold_associations_path || controller.scaffold_path("associations"))
    controller.send(:render_to_string, {:file=>filename, :layout=>false}) if File.file?(filename)
  end
  
  # Returns link to the scaffolded management page for the model if it was created by the scaffolding.
  def manage_link
    "<br />#{link_to("Manage #{@scaffold_plural_name.humanize.downcase}", :action => "manage#{@scaffold_suffix}")}" if @scaffold_methods.include?(:manage)
  end
  
  # Returns an appropriate scaffolded data entry form for the model, with any related error messages.
  def scaffold_form(action)
    "#{error_messages_for(@scaffold_singular_name)}\n#{form(@scaffold_singular_name, :action=>"#{action}#{@scaffold_suffix}", :submit_value=>"#{action.capitalize} #{@scaffold_singular_name.humanize.downcase}")}"
  end
  
  # Returns associated object's scaffold_name if column is an association, otherwise returns column value.
  def scaffold_value(entry, column)
    entry.send(column).methods.include?('scaffold_name') ? entry.send(column).scaffold_name : entry.send(column)
  end
end

module ActionController # :nodoc:
  # Two variables can be set that affect scaffolding, either as class variables
  # (which specifies the default for all classes) or instance variables (which
  # specifies the values for that class only).
  #
  # - scaffold_template_dir: the location of the scaffold templates (default:
  #   "#{File.dirname(__FILE__)}/../scaffolds" # the plugin's default scaffold directory)
  # - default_scaffold_methods: the default methods added by the scaffold function
  #   (default: [:manage, :show, :destroy, :edit, :new, :search, :merge, :browse] # all methods)
  class Base
    @@scaffold_template_dir = "#{File.dirname(__FILE__)}/../scaffolds"
    @@default_scaffold_methods = [:manage, :show, :destroy, :edit, :new, :search, :merge, :browse]
    cattr_accessor = :scaffold_template_dir, :default_scaffold_methods
    
    class << self
      # The location of the scaffold templates
      def scaffold_template_dir
        @scaffold_template_dir ||= @@scaffold_template_dir
      end
      
      # The methods that should be added by the scaffolding function by default
      def default_scaffold_methods
        @default_scaffold_methods ||= @@default_scaffold_methods
      end
      
      # Returns path to the given scaffold rhtml file
      def scaffold_path(template_name)
        File.join(scaffold_template_dir, template_name+'.rhtml')
      end
      
      # Normalizes scaffold options, allowing submission of symbols or arrays
      def normalize_scaffold_options(options)
        case options
          when Array then options
          when Symbol then [options]
          else []
        end
      end
      
      # Create controller instance method for returning results to the scaffold autocompletor
      # for the given model.
      def scaffold_auto_complete_for(object, options = {})
        define_method("scaffold_auto_complete_for_#{object}") do
          @items = object.to_s.camelize.constantize.scaffold_auto_complete_find(params[:id], options)
          render :inline => "<%= scaffold_auto_complete_result(@items) %>"
        end
      end
      
      # Setup scaffold auto complete for them model if it is requested by model
      # and it hasn't already been setup.
      def setup_scaffold_auto_complete_for(model_id)
        scaffold_auto_complete_for(model_id) if model_id.to_s.camelize.constantize.scaffold_use_auto_complete && !respond_to?("scaffold_auto_complete_for_#{model_id}")
      end
      
      # Setup scaffold_auto_complete_for for the given controller for all models
      # implementing scaffold autocompleting.  If scaffolding is used in multiple
      # controllers, scaffold_auto_complete_for methods for all models will be added
      # to all controllers.
      def setup_scaffold_auto_completes
        return if @scaffold_auto_completes_are_setup
        ActiveRecord::Base.all_models.each{|model| setup_scaffold_auto_complete_for(model.to_sym)}
        @scaffold_auto_completes_are_setup = true
      end
    end
    
    # Returns path to the given scaffold rhtml file
    def scaffold_path(template_name)
      self.class.scaffold_path(template_name)
    end
    
    private
    # Renders manually created page if it exists, otherwise renders a scaffold form.
    # If a layout is specified (either in the controller or as an option), use that layout,
    # otherwise uses the scaffolded layout.
    def render_scaffold_template(action, options = {}) # :doc:
      options = if template_exists?("#{self.class.controller_path}/#{action}")
        {:action=>action}.merge(options)
      else
        if active_layout || options.include?(:layout)
          {:file=>scaffold_path(action.split('_')[0]), :layout=>active_layout}.merge(options)
        else
          @content_for_layout = render_to_string({:file=>scaffold_path(action.split('_')[0])}.merge(options))
          {:file=>scaffold_path("layout")}
        end
      end
      render(options)
    end
    
    # Converts all items in the array to integers and discards non-zero values
    def multiple_select_ids(arr) # :doc:
      arr = [arr] unless arr.is_a?(Array)
      arr.collect{|x| x.to_i}.delete_if{|x| x == 0}
    end
    
    # Adds conditions for the scaffolded search query.  Uses LIKE OR ILIKE for string attributes,
    # IS TRUE|FALSE for boolean attributes, and = for other attributes.
    def scaffold_search_add_condition(conditions, record, field) # :doc:
      column = record.column_for_attribute(field)
      if column and column.klass == String
        if record.send(field).length > 0
          conditions[0] << "#{record.class.table_name}.#{field} #{record.class.scaffold_auto_complete_search_operator} ?"
          conditions << "%#{record.send(field)}%"
        end
      elsif column.klass == Object
        conditions[0] << "#{record.class.table_name}.#{field} IS #{record.send(field) ? 'TRUE' : 'FALSE'}"
      else
        conditions[0] << "#{record.class.table_name}.#{field} = ?"
        conditions << record.send(field)
      end
    end
  end
  
  module Scaffolding # :nodoc:
    module ClassMethods
      # Expands on the default Rails scaffold function.
      # Takes the following additional options:
      #
      # - :except: symbol or array of method symbols not to add
      # - :only: symbol or array of method symbols to use instead of the default
      # - :habtm: symbol or array of symbols of habtm associated classes,
      #   habtm scaffolds will be created for each one
      # - :setup_auto_completes: if set to false, don't create scaffold auto
      #   complete actions for all models
      #
      # The following method symbols are used to control the methods that get
      # added by the scaffold function:
      #
      # - :manage: Page that has links to all the other methods.  Also used
      #   as the index page unless :suffix=>true
      # - :show: Shows a select box with all objects, allowing the user to chose
      #   one, which then shows the attribute name and value for scaffolded fields
      # - :destroy: Shows a select box with all objects, allowing the user to chose
      #   one to delete
      # - :edit: Shows a select box with all objects, allowing the user to chose
      #   one to edit.  Also shows associations specified in the model's
      #   scaffold_associations, allowing you easy access to manage associated models,
      #   add new objects for has_many associations, and edit the has_and_belongs_to_many
      #   associations.
      # - :new: Form for creating new objects
      # - :search: Simple search form using the same attributes as the new/edit 
      #   form. The results page has links to show, edit, or destroy the object
      # - :merge: Brings up two select boxes each populated with all objects,
      #   allowing the user to pick one to merge into the other
      # - :browse: Browse all model objects, similar to the default Rails list scaffold 
      def scaffold(model_id, options = {})
        options.assert_valid_keys(:class_name, :suffix, :except, :only, :habtm, :setup_auto_completes)
        
        singular_name = model_id.to_s.underscore.singularize
        class_name    = options[:class_name] || singular_name.camelize
        plural_name   = singular_name.pluralize
        suffix        = options[:suffix] ? "_#{singular_name}" : ""
        add_methods = options[:only] ? normalize_scaffold_options(options[:only]) : self.default_scaffold_methods
        add_methods -= normalize_scaffold_options(options[:except]) if options[:except]
        normalize_scaffold_options(options[:habtm]).each{|habtm_class| scaffold_habtm(model_id, habtm_class, false)}
        setup_scaffold_auto_completes unless options[:setup_auto_completes] == false
        
        if add_methods.include?(:manage)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def manage#{suffix}
              render#{suffix}_scaffold "manage#{suffix}"
            end
          end_eval
          
          unless options[:suffix]
            module_eval <<-"end_eval", __FILE__, __LINE__
              def index
                manage
              end
            end_eval
          end
        end
        
        if add_methods.include?(:show) or add_methods.include?(:destroy) or add_methods.include?(:edit)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def list#{suffix}
              @scaffold_action ||= 'edit'
              unless #{class_name}.scaffold_use_auto_complete
                @#{plural_name} = #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
                @#{plural_name}.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if #{class_name}.scaffold_include
              end
              render#{suffix}_scaffold "list#{suffix}"
            end
          end_eval
        end
        
        if add_methods.include?(:show)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def show#{suffix}
              if params[:id]
                @#{singular_name} = #{class_name}.find(params[:id].to_i, :include=>#{class_name}.scaffold_include)
                render#{suffix}_scaffold
              else
                @scaffold_action = 'show'
                list#{suffix}
              end
            end
          end_eval
        end
        
        if add_methods.include?(:destroy)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def destroy#{suffix}
              if params[:id]
                #{class_name}.find(params[:id].to_i).destroy
                flash[:notice] = "#{singular_name.humanize} was successfully destroyed"
                redirect_to :action => "destroy#{suffix}"
              else
                @scaffold_action = 'destroy'
                list#{suffix}
              end
            end
          end_eval
        end
        
        if add_methods.include?(:edit)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def edit#{suffix}
              if params[:id]
                @#{singular_name} = #{class_name}.find(params[:id].to_i)
                render#{suffix}_scaffold
              else
                @scaffold_action = 'edit'
                list#{suffix}
              end
            end
            
            def update#{suffix}
              @#{singular_name} = #{class_name}.find(params[:id])
              @#{singular_name}.attributes = params[:#{singular_name}]
              
              if @#{singular_name}.save
                flash[:notice] = "#{singular_name.humanize} was successfully updated"
                redirect_to :action => "edit#{suffix}"
              else
                render#{suffix}_scaffold('edit')
              end
            end
          end_eval
        end
        
        if add_methods.include?(:new)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def new#{suffix}
              @#{singular_name} = #{class_name}.new(params[:#{singular_name}])
              render#{suffix}_scaffold
            end
            
            def create#{suffix}
              @#{singular_name} = #{class_name}.new(params[:#{singular_name}])
              if @#{singular_name}.save
                flash[:notice] = "#{singular_name.humanize} was successfully created"
                redirect_to :action => "new#{suffix}"
              else
                render#{suffix}_scaffold('new')
              end
            end
          end_eval
        end
        
        if add_methods.include?(:search)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def search#{suffix}
              @#{singular_name} = #{class_name}.new
              @scaffold_fields = @#{singular_name}.class.scaffold_fields
              @scaffold_nullable_fields = @#{singular_name}.class.scaffold_fields.collect do |field|
                reflection = @#{singular_name}.class.reflect_on_association(field.to_sym)
                reflection ? (reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key) : field
              end
              render#{suffix}_scaffold('search#{suffix}')
            end
            
            def results#{suffix}
              record = #{class_name}.new(params["#{singular_name}"])
              conditions = [[]]
              includes = []
              if params[:#{singular_name}]
                #{class_name}.scaffold_fields.each do |field|
                  reflection = #{class_name}.reflect_on_association(field.to_sym)
                  if reflection
                    includes << field.to_sym
                    field = (reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key).to_s
                  end
                  next if (params[:null] and params[:null].include?(field)) or (params[:notnull] and params[:notnull].include?(field))
                  scaffold_search_add_condition(conditions, record, field) if params[:#{singular_name}][field] and params[:#{singular_name}][field].length > 0
                end
              end
              params[:null].each {|field| conditions[0] << field + ' IS NULL' } if params[:null]
              params[:notnull].each {|field| conditions[0] << field + ' IS NOT NULL' } if params[:notnull]
              conditions[0] = conditions[0].join(' AND ')
              conditions[0] = '1=1' if conditions[0].length == 0
              @#{plural_name} = #{class_name}.find(:all, :conditions=>conditions, :include=>includes, :order=>#{class_name}.scaffold_select_order, :limit=>#{class_name}.scaffold_search_results_limit)
              render#{suffix}_scaffold('listtable#{suffix}')
            end
          end_eval
        end
      
        if add_methods.include?(:merge)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def merge#{suffix}
              unless #{class_name}.scaffold_use_auto_complete
                @#{plural_name} = #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
                @#{plural_name}.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if #{class_name}.scaffold_include
              end
              render#{suffix}_scaffold('merge#{suffix}')
            end
            
            def merge_update#{suffix}
              flash[:notice] = if #{class_name}.merge_records(params[:from].to_i, params[:to].to_i)
                "#{plural_name.humanize} were successfully merged"
              else "Error merging #{plural_name.humanize.downcase}"
              end
              redirect_to :action=>'merge#{suffix}'
            end
          end_eval
        end
        
        if add_methods.include?(:browse)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def browse#{suffix}
              @#{singular_name}_pages, @#{plural_name} = paginate(:#{plural_name}, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_fields.collect{|field| field.to_sym if #{class_name}.reflect_on_association(field.to_sym)}.compact, :per_page => #{class_name}.scaffold_browse_records_per_page)
              render#{suffix}_scaffold('listtable#{suffix}')
            end
          end_eval
        end
        
        module_eval <<-"end_eval", __FILE__, __LINE__
          add_template_helper(ScaffoldHelper)
          private
            def render#{suffix}_scaffold(action=nil, options={})
              action ||= caller_method_name(caller)
              @scaffold_class = #{class_name}
              @scaffold_singular_name, @scaffold_plural_name = "#{singular_name}", "#{plural_name}"
              @scaffold_methods = #{add_methods.inspect}
              @scaffold_suffix = "#{suffix}"
              @scaffold_singular_object = @#{singular_name}
              @scaffold_plural_object = @#{plural_name}
              add_instance_variables_to_assigns
              render_scaffold_template(action, options)
            end
            
            def caller_method_name(caller)
              caller.first.scan(/`(.*)'/).first.first # ' ruby-mode
            end
        end_eval
      end
      
      # Scaffolds a habtm association for two classes using two select boxes, or
      # a select box for removing associations and an autocompleting text box for
      # adding associations. By default, scaffolds the association both ways.
      def scaffold_habtm(singular, many, both_ways = true)
        singular_class, many_class = singular.to_s.singularize.camelize.constantize, many.to_s.singularize.camelize.constantize
        singular_name, many_class_name = singular_class.name, many_class.name
        many_name = many_class.name.pluralize.underscore
        reflection = singular_class.reflect_on_association(many_name.to_sym)
        return false if reflection.nil? or reflection.macro != :has_and_belongs_to_many
        foreign_key = reflection.options[:foreign_key] || singular_class.table_name.classify.foreign_key
        association_foreign_key = reflection.options[:association_foreign_key] || many_class.table_name.classify.foreign_key
        join_table = reflection.options[:join_table] || ( singular_name < many_class_name ? '#{singular_name}_#{many_class_name}' : '#{many_class_name}_#{singular_name}')
        suffix = "_#{singular_name.underscore}_#{many_name}" 
        setup_scaffold_auto_complete_for(many_class_name.underscore.to_sym)
        module_eval <<-"end_eval", __FILE__, __LINE__
          def edit#{suffix}
            @singular_name = "#{singular_name}" 
            @many_name = "#{many_name.gsub('_',' ')}" 
            @singular_object = #{singular_name}.find(params[:id])
            @many_class = #{many_class_name}
            @items_to_remove = #{many_class_name}.find(:all, :conditions=>["#{many_class.primary_key} IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", params[:id].to_i]#{', :order=>"'+many_class.scaffold_select_order+'"' if many_class.scaffold_select_order}).collect{|item| [item.scaffold_name, item.id]}
            unless #{many_class}.scaffold_use_auto_complete
              @items_to_add = #{many_class_name}.find(:all, :conditions=>["#{many_class.primary_key} NOT IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", params[:id].to_i]#{', :order=>"'+many_class.scaffold_select_order+'"' if many_class.scaffold_select_order}).collect{|item| [item.scaffold_name, item.id]}
            end
            @scaffold_update_page = "update#{suffix}" 
            render_scaffold_template("habtm")
          end
          
          def update#{suffix}
            flash[:notice] = begin
              singular_item = #{singular_name}.find(params[:id])
              singular_item.#{many_name}.push(#{many_class_name}.find(multiple_select_ids(params[:add]))) if params[:add] && !params[:add].empty?
              singular_item.#{many_name}.delete(#{many_class_name}.find(multiple_select_ids(params[:remove]))) if params[:remove] && !params[:remove].empty?
              "Updated #{singular_name}'s #{many_name} successfully" 
            rescue ::ActiveRecord::StatementInvalid
              "Error updating #{singular_name}'s #{many_name}" 
            end
            redirect_to(:action=>"edit#{suffix}", :id=>params[:id])
          end
        end_eval
        both_ways ? scaffold_habtm(many_class, singular_class, false) : true
      end
      
      # Scaffolds all models in the Rails app, with all associations.  Scaffolds all 
      # models in the models directory if no arguments are given, otherwise just
      # scaffolds for those models.
      def scaffold_all_models(*models)
        models = ActiveRecord::Base.all_models if models.length == 0
        models.each do |model|
          scaffold model.to_sym, :suffix=>true, :habtm=>model.to_s.camelize.constantize.reflect_on_all_associations.collect{|r|r.name if r.macro == :has_and_belongs_to_many}.compact
        end
        module_eval <<-"end_eval", __FILE__, __LINE__
          def index
            @models = #{models.inspect}
            render_scaffold_template("index")
          end
        end_eval
      end
    end
  end
end
