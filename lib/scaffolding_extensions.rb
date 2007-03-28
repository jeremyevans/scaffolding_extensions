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
  # - scaffold_default_column_names: Override the visible names of columns for each attribute (default: {})
  # - scaffold_association_list_class: Override the html class for the association list in the edit view
  #   (default: '')
  # - scaffold_browse_default_records_per_page - The default number of records per page to show in the
  #   browse scaffold (default: 10)
  # - scaffold_search_results_default_limit - The default limit on scaffolded search results.  If nil,
  #   the search results will be displayed on one page instead of being paginated (default: 10)
  # - scaffold_habtm_with_ajax_default - Whether or not to use Ajax (instead of a separate page) for 
  #   habtm associations for all models (default: false)
  # - scaffold_load_associations_with_ajax_default - Whether or not to use Ajax to load the display of
  #   associations on the edit page, used if the default display is too slow (default: false)
  # - scaffold_auto_complete_default_options: Hash containing the default options to use for the scaffold
  #   autocompleter (default: {:enable=>false, :sql_name=>'LOWER(name)', :text_field_options=>{:size=>50},
  #   :format_string=>:substring, :search_operator=>'LIKE', :results_limit=>10, :phrase_modifier=>:downcase,
  #   :skip_style=>false})
  #
  # Modifying instance variables in each class affects scaffolding for that class only.
  # Available instance variables:
  #
  # - scaffold_fields: List of field names to include in the scaffolded forms.
  #   Values in the list should be either actual fields names, or names of belongs_to
  #   associations (in which case select boxes will be used in the scaffolded forms).
  #   Uses content_columns + belongs_to associations if not specified.
  #   (example: %w'name number rating')
  # - scaffold_(new|edit|show|search|browse)_fields: Different scaffold actions can have different
  #   fields displayed.  Defaults to scaffold_fields if not specified.
  # - scaffold_select_order: SQL fragment string setting the order in which scaffolded records are shown
  #   (example: 'firstname, lastname')
  # - scaffold_include: Any associations that should be included by default when displaying the
  #   scaffold name.  Eager loading is used so that N+1 queries aren't used for displaying N
  #   records, assuming that associated records used in scaffold_name are included in this.
  #   (example: [:artist, :album])
  # - scaffold_(search|browse)_(select_order|include): Search and browse can have their own
  #   select order and include.  For select order, defaults to scaffold_select_order if not given.
  #   For include, defaults to the subset of scaffold_(search|browse)_fields that are 
  #   associations instead of attributes.
  # - scaffold_column_names: Override the visible names of columns for each attribute.
  #   By default, this is just the humanized name. (example: {:modelnum=>'Model Number'})
  # - scaffold_associations: List of associations to display on the scaffolded edit page for the object.
  #   Uses all associations if not specified (example: %w'artist albums')
  # - scaffold_associations_path: String path to the template to use to render the associations
  #   for the show/edit page.  Uses the controller's scaffold path if not specified.
  #   (example: "#{RAILS_ROOT}/lib/model_associations.rhtml")
  # - scaffold_habtm_ajax_path: String path to the template to use to render the habtm ajax entries
  #   for the edit page.  Uses the controller's scaffold path if not specified.
  #   (example: "#{RAILS_ROOT}/lib/model_habtm_ajax.rhtml")
  # - scaffold_browse_records_per_page - The number of records per page to show in the
  #   browse scaffold.  Uses scaffold_browse_default_records_per_page if not specified (example: 25)
  # - scaffold_search_results_limit - The limit on the number of records in the scaffolded search
  #   results page (example: 25)
  # - scaffold_habtm_with_ajax - Whether to use Ajax for habtm associations for this class (example: true)
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
    @@scaffold_default_column_names = {}
    @@scaffold_browse_default_records_per_page = 10
    @@scaffold_search_results_default_limit = 10
    @@scaffold_habtm_with_ajax_default = false
    @@scaffold_load_associations_with_ajax_default = false
    @@scaffold_auto_complete_default_options = {:enable=>false, :sql_name=>'LOWER(name)',
      :text_field_options=>{:size=>50}, :format_string=>:substring, :search_operator=>'LIKE',
      :results_limit=>10, :phrase_modifier=>:downcase, :skip_style=>false}
    cattr_accessor :scaffold_convert_text_to_string, :scaffold_table_classes, :scaffold_column_types, :scaffold_column_options_hash, :scaffold_association_list_class, :scaffold_auto_complete_default_options, :scaffold_browse_default_records_per_page, :scaffold_search_results_default_limit, :scaffold_default_column_names, :scaffold_habtm_with_ajax_default, :scaffold_load_associations_with_ajax_default, :instance_writer => false
    
    class << self
      attr_accessor :scaffold_select_order, :scaffold_include, :scaffold_associations_path, :scaffold_habtm_ajax_path
      
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
      
      def interpolate_conditions(conditions) # :nodoc:
        return conditions unless conditions
        aliased_table_name = table_name
        instance_eval("%@#{conditions.gsub('@', '\@')}@")
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
        @scaffold_associations ||= reflect_on_all_associations.collect{|r|r.name.to_s unless (r.options.include?(:through) || r.options.include?(:polymorphic))}.compact.sort
      end
      
      # Array of all habtm reflections for this model's scaffold_associations
      def scaffold_habtm_reflections
        @scaffold_habtm_reflections ||= (scaffold_associations.collect do |association|
          reflection = reflect_on_association(association.to_sym)
          reflection if reflection && reflection.macro == :has_and_belongs_to_many
        end).compact
      end
      
      # Returns the list of fields to display on the scaffolded forms. Defaults
      # to displaying all usually scaffolded columns with the addition of belongs
      # to associations that aren't polymorphic.
      #
      # This the basis for the display of fields in the scaffolds.  Each type of scaffold
      # that displays fields (new, edit, show, search, and browse), can have a different
      # set of fields by overriding scaffold_*_fields (e.g. scaffold_new_fields) via a
      # class method or class instance variable.
      def scaffold_fields
        return @scaffold_fields if @scaffold_fields
        @scaffold_fields = columns.reject{|c| c.primary || c.name =~ /_count$/ || c.name == inheritance_column }.collect{|c| c.name}
        reflect_on_all_associations.each do |reflection|
          next if reflection.macro != :belongs_to || reflection.options.include?(:polymorphic)
          @scaffold_fields.delete((reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key).to_s)
          @scaffold_fields.push(reflection.name.to_s)
        end
        @scaffold_fields.sort!
        @scaffold_fields
      end
      
      %w'new edit show search browse'.each do |type|
        module_eval <<-"end_eval", __FILE__, __LINE__
          def scaffold_#{type}_fields
            @scaffold_#{type}_fields ||= scaffold_fields
          end
          
          def scaffold_#{type}_fields_replacing_associations
            @scaffold_#{type}_fields_replacing_associations ||= scaffold_fields_replacing_associations(scaffold_#{type}_fields)
          end
        end_eval
      end
      
      %w'search browse'.each do |type|
        module_eval <<-"end_eval", __FILE__, __LINE__
          def scaffold_#{type}_select_order
            @scaffold_#{type}_select_order ||= scaffold_select_order
          end
        end_eval
      end
      
      # A list of symbols for including in the query for the search scaffold
      def scaffold_search_include
        @scaffold_search_include ||= scaffold_search_fields.collect{|field| field.to_sym if reflection = reflect_on_association(field.to_sym)}.compact
      end
      
      # A list of symbols for including in the query for the browse scaffold
      def scaffold_browse_include
        @scaffold_browse_include ||= scaffold_browse_fields.collect{|field| field.to_sym if reflection = reflect_on_association(field.to_sym)}.compact
      end
      
      # If search pagination is enabled (by default it is if 
      # scaffold_search_results_limit is not nil)
      def search_pagination_enabled?
        !scaffold_search_results_limit.nil?
      end
      
      # scaffold_fields with associations replaced by foreign key fields
      def scaffold_fields_replacing_associations(fields = nil)
        if fields.nil?
          @scaffold_fields_replacing_associations ||= scaffold_fields_replacing_associations(scaffold_fields)
        else
          fields.collect do |field|
            reflection = reflect_on_association(field.to_sym)
            reflection ? (reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key) : field
          end
        end
      end
      
      # List of human visible names and field names to use for NULL/NOT NULL fields on the scaffolded search page
      def scaffold_search_null_options
        @scaffold_search_null_options ||= scaffold_search_fields_replacing_associations.collect do |field|
          [scaffold_column_name(field), field] if columns_hash[field]
        end.compact
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
      
      # Returns the visable name for a given attribute
      def scaffold_column_name(column_name)
        @scaffold_column_names ||= scaffold_default_column_names
        @scaffold_column_names[column_name.to_sym] || column_name.to_s.humanize
      end
      
      # The number of records to show on each page when using the browse scaffold
      def scaffold_browse_records_per_page
        @scaffold_browse_records_per_page ||= scaffold_browse_default_records_per_page
      end
      
      # The maximum number of results to show on the scaffolded search results page
      def scaffold_search_results_limit
        @scaffold_search_results_limit ||= scaffold_search_results_default_limit
      end
      
      # Whether to use Ajax when scaffolding habtm associations for this model
      def scaffold_habtm_with_ajax
        @scaffold_habtm_with_ajax ||= scaffold_habtm_with_ajax_default
      end
      
      # Whether to use Ajax when loading associations on the edit page
      def scaffold_load_associations_with_ajax
        @scaffold_load_associations_with_ajax ||= scaffold_load_associations_with_ajax_default
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
      
      # Don't use the style tags, used if they are already defined in the CSS file
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
    
    # Only update the attributes given in allowed_fields
    def update_scaffold_attributes(allowed_fields, new_attributes)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!
      attributes.delete_if{|k,v| !allowed_fields.include?(k.split('(')[0])}
      
      multi_parameter_attributes = []
      attributes.each do |k, v|
        k.include?("(") ? multi_parameter_attributes << [ k, v ] : send(k + "=", v)
      end
      
      assign_multiparameter_attributes(multi_parameter_attributes)
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
      # Takes record's scaffold_fields (or specified fields) and creates the 
      # necessary form fields html fragment.  Uses a table by default so that
      # everything lines up nicely.
      def all_input_tags(record, record_name, options)
        input_block = options[:input_block] || default_input_block
        rows = (options[:fields] || record.class.scaffold_fields).collect do |field|
          input_block.call(record_name, record.class.reflect_on_association(field.to_sym) || record.column_for_attribute(field) || field) 
        end
        all_input_tags_wrapper(record, rows)
      end
      
      # Get label and widget for record_name and column
      def input_tag_label_and_widget(record_name, column)
          column_name = column.send(column.is_a?(String) || column.is_a?(Symbol) ? :to_s : :name)
          label_id, tag = if column.class.name =~ /Reflection/
            next unless column.macro == :belongs_to
            ["#{record_name}_#{column.options[:foreign_key] || column.klass.table_name.classify.foreign_key}", association_select_tag(record_name, column_name)]
          else
            ["#{record_name}_#{column_name}", input(record_name, column_name) || text_field(record_name, column_name)]
          end
          ["<label for='#{label_id}'>#{@scaffold_class ? @scaffold_class.scaffold_column_name(column_name) :  column_name.to_s.humanize}</label>", tag]
      end
        
      # Wrap all input tags (table rows) in a table
      def all_input_tags_wrapper(record, rows)
        "\n<table class='#{record.class.scaffold_table_class :form}'><tbody>\n#{rows.join}</tbody></table>\n"
      end
      
      # Wrap label and widget in table row
      def input_tag_wrapper(label, tag)
          "<tr><td>#{label}</td><td>#{tag}</td></tr>\n"
      end
      
      # Create html fragment for field for record_name and column
      def default_input_block
        Proc.new{|record_name, column| input_tag_wrapper(*input_tag_label_and_widget(record_name, column))}
      end
      
      # Returns a select box displaying all possible records in the associated model
      # that can be associated with this model.  If scaffold autocompleting is turned
      # on for the associated model, uses an autocompleting text box. 
      def association_select_tag(record, association)
        reflection = record.camelize.constantize.reflect_on_association(association)
        foreign_key = reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key
        if reflection.klass.scaffold_use_auto_complete
          scaffold_text_field_with_auto_complete(record, foreign_key, reflection.klass.name.underscore)
        else
          items = reflection.klass.find(:all, :order => reflection.klass.scaffold_select_order, :conditions => reflection.klass.interpolate_conditions(reflection.options[:conditions]), :include=>reflection.klass.scaffold_include)
          select(record, foreign_key, items.collect{|i| [i.scaffold_name, i.id]}, {:include_blank=>true})
        end
      end
      
      # Returns a select box displaying the records for the associated model that
      # are not already associated with this record.  If scaffold autocompleting is
      # used, uses an autocompleting text box.
      def association_ajax_select_tag(id, record, reflection)
        if reflection.klass.scaffold_use_auto_complete
          scaffold_text_field_tag_with_auto_complete(id, reflection.klass)
        else
          singular_class = record.class
          foreign_key = reflection.options[:foreign_key] || singular_class.table_name.classify.foreign_key
          association_foreign_key = reflection.options[:association_foreign_key] || reflection.klass.table_name.classify.foreign_key
          join_table = reflection.options[:join_table] || ( singular_class.table_name < reflection.klass.table_name ? '#{singular_class.table_name}_#{reflection.klass.table_name}' : '#{reflection.klass.table_name}_#{singular_class.table_name}')
          items = reflection.klass.find(:all, :order => reflection.klass.scaffold_select_order, :conditions =>["#{reflection.klass.table_name}.#{reflection.klass.primary_key} NOT IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", record.id], :include=>reflection.klass.scaffold_include)
          select_tag(id, "<option></option>" << items.collect{|item| "<option value='#{item.id}' id='#{id}_#{item.id}'>#{h item.scaffold_name}</option>"}.join("\n"))
        end
      end
    end
    
    # Methods used to implement scaffold autocompleting
    module JavaScriptMacrosHelper
      # Line item with button for removing the associated record from the current record
      def scaffold_habtm_association_line_item(record, record_name, associated_record, associated_record_name)
        "<li id='#{record_name}_#{record.id}_#{associated_record_name}_#{associated_record.id}'>#{link_to_or_text(associated_record_name.humanize, :action=>"manage_#{associated_record.class.name.underscore}")} - #{link_to_or_text(h(associated_record.scaffold_name), :action=>"edit_#{associated_record.class.name.underscore}", :id=>associated_record.id)} #{button_to_remote('Remove', :url=>url_for(:action=>"remove_#{associated_record_name}_from_#{record_name}", :id=>record.id, "#{record_name}_#{associated_record_name}_id".to_sym=>associated_record.id))}</li>"
      end
      
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
      
      # Formats the records returned by scaffold autocompleting to be displayed
      # (an unordered list by default).
      def scaffold_auto_complete_result(entries)
        return unless entries
        content_tag("ul", entries.map{|entry| content_tag("li", h(entry.scaffold_name_with_id))}.uniq)
      end
    end
    
    module PrototypeHelper
      # Button that submits via Ajax, similar to link_to_remote
      def button_to_remote(name, options = {})  
        "#{form_remote_tag(options)}<input type='submit' value=#{name.inspect} /></form>"
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
          when :file
            to_input_field_tag("file", options)
        end
      end
      
      # Returns three valued select widget, for null, false, and true, with the appropriate
      # value selected
      def to_boolean_select_tag(options = {})
        options = options.stringify_keys
        add_default_name_and_id(options)
        "<select#{tag_options(options)}><option value=''#{selected(value(object).nil?)}>&nbsp;</option><option value='f'#{selected(value(object) == false)}>False</option><option value='t'#{selected(value(object))}>True</option></select>"
      end
      
      # Returns XHTML compliant fragment for whether the value is selected or not
      def selected(value)
        value ? " selected='selected'" : '' 
      end
      
      # Allow overriding of the column type by asking the model for the appropriate column type.
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
  
  # Returns html fragment containing text/select boxes to add associated records
  # to the current record, and line items with buttons to remove associated records
  # from the current record.
  def habtm_ajax_associations
    filename = (@scaffold_class.scaffold_habtm_ajax_path || controller.scaffold_path("habtm_ajax"))
    controller.send(:render_to_string, {:file=>filename, :layout=>false}) if File.file?(filename)
  end
  
  # Returns link to the scaffolded management page for the model if it was created by the scaffolding.
  def manage_link
    "<br />#{link_to("Manage #{@scaffold_plural_name.humanize.downcase}", :action => "manage#{@scaffold_suffix}")}" if @scaffold_methods.include?(:manage)
  end
  
  # Whether the form should be a multipart form (i.e. contains a file field)
  def multipart?(column_names)
    return false unless column_names
    column_names.each { |column_name| return true if @scaffold_class.scaffold_column_type(column_name) == :file }
    false
  end
  
  # Returns an appropriate scaffolded data entry form for the model, with any related error messages.
  def scaffold_form(action, options = {})
    "#{error_messages_for(@scaffold_singular_name)}\n#{form(@scaffold_singular_name, {:action=>"#{action}#{@scaffold_suffix}", :submit_value=>"#{action.capitalize} #{@scaffold_singular_name.humanize.downcase}", :multipart=>multipart?(options[:fields])}.merge(options))}"
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
    cattr_accessor :scaffold_template_dir, :default_scaffold_methods, :instance_writer => false
    
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
      
      def scaffold_method(method_name) # :nodoc:
        "alias_method :#{method_name}, :_#{method_name}; private :_#{method_name};"
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
      
      # Setup scaffold auto complete for the model if it is requested by model
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
    # Redirect to the appropriate form for the scaffolded model
    #
    # In addition to scaffold_redirect, there is also uses scaffold_#{action}_redirect
    # (e.g. scaffold_(new|edit|destroy|merge)_redirect), which makes the redirect modifiable per action.
    # So if you to redirect to the edit page of an object just after creating it,
    # you may want to redefine scaffold_new_redirect:
    #
    #  def scaffold_edit_redirect(suffix)
    #    redirect_to({:action => "edit#{suffix}", :id=>params[:id].to_i})
    #  end
    #
    # You can also define redirects for a given action and a model:
    #
    #  def scaffold_edit_artist_redirect
    #    redirect_to({:controller=>'artists', :action=>"profile", :id=>params[:id].to_i})
    #  end
    def scaffold_redirect(action, suffix)
      redirect_to({:action => "#{action}#{suffix}", :id=>nil})
    end
    
    %w'destroy edit new merge'.each do |action|
      module_eval <<-"end_eval", __FILE__, __LINE__
        def scaffold_#{action}_redirect(suffix)
          action = 'scaffold_#{action}\#{suffix}_redirect'
          respond_to?(action) ? send(action) : scaffold_redirect("#{action}", suffix)
        end
      end_eval
    end
    
    # Redirect to the appropriate page after a habtm associations update
    #
    # Because the habtm update form redirects even on failure, both the suffix
    # and a success flag are passed.
    #
    # Like scaffold_redirect, it's possible to change the redirect per model, via:
    #
    #  def scaffold_habtm_artist_albums_redirect(suffix)
    #    redirect_to({:controller=>'artists', :action=>"profile", :id=>params[:id].to_i})
    #  end
    #
    def scaffold_habtm_redirect(suffix, success)
      action = 'scaffold_habtm#{suffix}_redirect'
      respond_to?(action) ? send(action, success) : redirect_to(:action=>"edit#{suffix}", :id=>params[:id].to_i)
    end

    def caller_method_name(caller) # :nodoc:
      x = caller.first.scan(/`(.*)'/).first.first
    end
    
    # Renders manually created page if it exists, otherwise renders a scaffold form.
    # If a layout is specified (either in the controller or as an option), use that layout,
    # otherwise uses the scaffolded layout.
    def render_scaffold_template(action, options = {}) # :doc:
      options = if template_exists?("#{self.class.controller_path}/#{action}")
        {:action=>action}.merge(options)
      elsif options.include?(:inline)
        options
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
    
    # Adds conditions for the scaffolded search query.  Uses a search for string attributes,
    # IS TRUE|FALSE for boolean attributes, and = for other attributes.
    def scaffold_search_add_condition(conditions, record, field) # :doc:
      return unless column = record.column_for_attribute(field)
      if column.klass == String
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
      # - :generate: instead of evaluating the code produced, it outputs the code
      #   functioning as a poor man's generator
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
        options.assert_valid_keys(:class_name, :suffix, :except, :only, :habtm,
          :setup_auto_completes, :scaffold_all_models, :generate)
        
        code = ''
        singular_name = model_id.to_s.underscore
        class_name    = options[:class_name] || singular_name.camelize
        singular_class = class_name.constantize
        plural_name   = singular_name.pluralize
        suffix        = options[:suffix] ? "_#{singular_name}" : ""
        add_methods = options[:only] ? normalize_scaffold_options(options[:only]) : self.default_scaffold_methods
        add_methods -= normalize_scaffold_options(options[:except]) if options[:except]
        normalize_scaffold_options(options[:habtm]).each{|habtm_association| code << scaffold_habtm(model_id, habtm_association, (singular_class.scaffold_habtm_with_ajax ? {:ajax=>true, :suffix=>suffix} : {}).merge(:generate=>options[:generate])).to_s}
        setup_scaffold_auto_completes unless options[:setup_auto_completes] == false
        
        if add_methods.include?(:manage)
          code << <<-"end_eval"
            def _manage#{suffix}
              @scaffold_all_models ||= #{options[:scaffold_all_models] ? 'true' : 'false'}
              render#{suffix}_scaffold "manage#{suffix}"
            end
            #{scaffold_method("manage#{suffix}")}
            
          end_eval
          
          unless options[:suffix]
            code << <<-"end_eval"
              def index
                manage
              end
              
            end_eval
          end
        end
        
        if add_methods.include?(:show) or add_methods.include?(:destroy) or add_methods.include?(:edit)
          code << <<-"end_eval"
            def list#{suffix}
              unless #{singular_class.scaffold_use_auto_complete}
                @#{plural_name} ||= #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
              end
              render#{suffix}_scaffold "list#{suffix}"
            end
            private :list#{suffix}
            
          end_eval
        end
        
        if add_methods.include?(:show)
          code << <<-"end_eval"
            def _show#{suffix}
              if params[:id]
                @#{singular_name} ||= #{class_name}.find(params[:id].to_i)
                @scaffold_associations_readonly = true
                render#{suffix}_scaffold
              else
                @scaffold_action = 'show'
                list#{suffix}
              end
            end
            #{scaffold_method("show#{suffix}")}
            
          end_eval
        end
        
        if add_methods.include?(:destroy)
          code << <<-"end_eval"
            def _destroy#{suffix}
              if params[:id]
                #{class_name}.find(params[:id].to_i).destroy
                flash[:notice] = "#{singular_name.humanize} was successfully destroyed"
                scaffold_destroy_redirect('#{suffix}')
              else
                @scaffold_action = 'destroy'
                list#{suffix}
              end
            end
            #{scaffold_method("destroy#{suffix}")}
            
          end_eval
        end
        
        if add_methods.include?(:edit)
          code << <<-"end_eval"
            def _edit#{suffix}
              if params[:id]
                @#{singular_name} ||= #{class_name}.find(params[:id].to_i)
                render#{suffix}_scaffold
              else
                @scaffold_action = 'edit'
                list#{suffix}
              end
            end
            #{scaffold_method("edit#{suffix}")}
            
            def _update#{suffix}
              @#{singular_name} ||= #{class_name}.find(params[:id])
              @#{singular_name}.update_scaffold_attributes(#{class_name}.scaffold_edit_fields_replacing_associations, params[:#{singular_name}])
              
              if @#{singular_name}.save
                flash[:notice] = "#{singular_name.humanize} was successfully updated"
                scaffold_edit_redirect('#{suffix}')
              else
                render#{suffix}_scaffold('edit')
              end
            end
            #{scaffold_method("update#{suffix}")}
            
          end_eval
          
          if singular_class.scaffold_load_associations_with_ajax
            code << <<-"end_eval"
            def _associations#{suffix}
              @#{singular_name} ||= #{class_name}.find(params[:id].to_i)
              render#{suffix}_scaffold('associations', :inline=>"<%= habtm_ajax_associations if @scaffold_class.scaffold_habtm_with_ajax %>\n<%= association_links %>\n", :layout=>false)
            end
            #{scaffold_method("associations#{suffix}")}
            
            end_eval
          end
        end
        
        if add_methods.include?(:new)
          code << <<-"end_eval"
            def _new#{suffix}
              @#{singular_name} ||= #{class_name}.new(params[:#{singular_name}])
              render#{suffix}_scaffold
            end
            #{scaffold_method("new#{suffix}")}
            
            def _create#{suffix}
              @#{singular_name} ||= #{class_name}.new
              @#{singular_name}.update_scaffold_attributes(#{class_name}.scaffold_new_fields_replacing_associations, params[:#{singular_name}])
              if @#{singular_name}.save
                flash[:notice] = "#{singular_name.humanize} was successfully created"
                params[:id] = @#{singular_name}.id
                scaffold_new_redirect('#{suffix}')
              else
                render#{suffix}_scaffold('new')
              end
            end
            #{scaffold_method("create#{suffix}")}
            
          end_eval
        end
        
        if add_methods.include?(:search)
          code << <<-"end_eval"
            def _search#{suffix}
              unless @#{singular_name}
                @#{singular_name} ||= #{class_name}.new
                #{class_name}.column_names.each{|key| @#{singular_name}[key] = nil }
              end
              render#{suffix}_scaffold('search#{suffix}')
            end
            #{scaffold_method("search#{suffix}")}
            
            def _results#{suffix}
              record = #{class_name}.new
              record.update_scaffold_attributes(#{class_name}.scaffold_search_fields_replacing_associations, params[:#{singular_name}])
              conditions = [[]]
              
              limit, offset = nil, nil
              if #{singular_class.search_pagination_enabled?}
                @scaffold_search_results_form_params = {"#{singular_name}"=>{}, :notnull=>[], :null=>[]}
                @scaffold_search_results_page = params[:page].to_i > 1 ? params[:page].to_i : 1
                @scaffold_search_results_page -= 1 if params[:page_previous]
                @scaffold_search_results_page += 1 if params[:page_next]
                limit = #{singular_class.scaffold_search_results_limit + 1}
                offset = @scaffold_search_results_page > 1 ? (limit-1)*(@scaffold_search_results_page - 1) : nil
              end
              
              if params[:#{singular_name}]
                #{class_name}.scaffold_search_fields_replacing_associations.each do |field|
                  next if (params[:null] && params[:null].include?(field)) || (params[:notnull] && params[:notnull].include?(field)) || !params[:#{singular_name}][field] || params[:#{singular_name}][field].length == 0
                  scaffold_search_add_condition(conditions, record, field)
                  @scaffold_search_results_form_params["#{singular_name}"][field] = params[:#{singular_name}][field] if #{singular_class.search_pagination_enabled?}
                end
              end
              
              #{class_name}.scaffold_search_fields_replacing_associations.each do |field|
                if params[:null] && params[:null].include?(field)
                  conditions[0] << "#{singular_class.table_name}.\#{field} IS NULL"
                  @scaffold_search_results_form_params[:null] << field if #{singular_class.search_pagination_enabled?}
                end
                if params[:notnull] && params[:notnull].include?(field)
                  conditions[0] << "#{singular_class.table_name}.\#{field} IS NOT NULL"
                  @scaffold_search_results_form_params[:notnull] << field if #{singular_class.search_pagination_enabled?}
                end
              end
              
              conditions[0] = conditions[0].join(' AND ')
              conditions = nil if conditions[0].length == 0
              @#{plural_name} = #{class_name}.find(:all, :conditions=>conditions, :include=>#{class_name}.scaffold_search_include, :order=>#{class_name}.scaffold_search_select_order, :limit=>limit, :offset=>offset)
              @scaffold_search_results_page_next = true if #{singular_class.search_pagination_enabled?} && @#{plural_name}.length == #{singular_class.scaffold_search_results_limit+1} && @#{plural_name}.pop
              @scaffold_fields_method = :scaffold_search_fields
              render#{suffix}_scaffold('listtable#{suffix}')
            end
            #{scaffold_method("results#{suffix}")}
            
          end_eval
        end
      
        if add_methods.include?(:merge)
          code << <<-"end_eval"
            def _merge#{suffix}
              unless #{singular_class.scaffold_use_auto_complete}
                @#{plural_name} ||= #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
              end
              render#{suffix}_scaffold('merge#{suffix}')
            end
            #{scaffold_method("merge#{suffix}")}
            
            def _merge_update#{suffix}
              flash[:notice] = if #{class_name}.merge_records(params[:from].to_i, params[:to].to_i)
                "#{plural_name.humanize} were successfully merged"
              else "Error merging #{plural_name.humanize.downcase}"
              end
              scaffold_merge_redirect('#{suffix}')
            end
            #{scaffold_method("merge_update#{suffix}")}
            
          end_eval
        end
        
        if add_methods.include?(:browse)
          code << <<-"end_eval"
            def _browse#{suffix}
              @#{singular_name}_pages, @#{plural_name} = paginate(:#{plural_name}, :class_name=>'#{class_name}', :order=>#{class_name}.scaffold_browse_select_order, :include=>#{class_name}.scaffold_browse_include, :per_page => #{singular_class.scaffold_browse_records_per_page}) unless @#{singular_name}_pages && @#{plural_name}
              @scaffold_fields_method = :scaffold_browse_fields
              render#{suffix}_scaffold('listtable#{suffix}')
            end
            #{scaffold_method("browse#{suffix}")}
            
          end_eval
        end
        
        code << <<-"end_eval"
          add_template_helper(ScaffoldHelper)
          
          private
            def render#{suffix}_scaffold(action=nil, options={})
              action ||= caller_method_name(caller)
              action = action[1..-1] if action[0...1] == '_' 
              @scaffold_class ||= #{class_name}
              @scaffold_singular_name ||= "#{singular_name}"
              @scaffold_plural_name ||= "#{plural_name}"
              @scaffold_methods ||= #{add_methods.inspect}
              @scaffold_suffix ||= "#{suffix}"
              @scaffold_singular_object ||= @#{singular_name}
              @scaffold_plural_object ||= @#{plural_name}
              add_instance_variables_to_assigns
              render_scaffold_template(action, options)
            end
        end_eval
        
        options[:generate] ? code : module_eval(code, __FILE__)
      end
      
      # Scaffolds a habtm association for two classes using two select boxes, or
      # a select box for removing associations and an autocompleting text box for
      # adding associations. By default, scaffolds the association both ways.
      # 
      # The new way of calling this is with symbols naming the model and the
      # association, and an optional hash of options.  The old method of having
      # an optional true/false flag still works.
      #
      # Possibly options:
      # - :both_ways - scaffold the association both ways
      # - :suffix - only needed for redirects for non-Ajax browsers using the ajax form, used by scaffold      
      # - :generate - return code generated instead of evaluating it
      def scaffold_habtm(singular, many, options = true)
        options = options.is_a?(Hash) ? Hash.new.merge(options) : {:both_ways=>options}
        singular_class = singular.to_s.camelize.constantize
        singular_name = singular_class.name
        reflection = singular_class.reflect_on_association(many.to_s.pluralize.underscore.to_sym)
        return false if reflection.nil? or reflection.macro != :has_and_belongs_to_many
        many_class = (reflection.options[:class_name] || many.to_s.camelize).constantize
        many_class_name = many_class.name
        many_name = many.to_s.pluralize.underscore
        setup_scaffold_auto_complete_for(many_class_name.underscore.to_sym)
        foreign_key = reflection.options[:foreign_key] || singular_class.table_name.classify.foreign_key
        association_foreign_key = reflection.options[:association_foreign_key] || many_class.table_name.classify.foreign_key
        join_table = reflection.options[:join_table] || ( singular_class.table_name < many_class.table_name ? '#{singular_class.table_name}_#{many_class.table_name}' : '#{many_class.table_name}_#{singular_class.table_name}')
        code = if options[:ajax]
          suffix = options[:suffix]
          <<-"end_eval"
            def add_#{many}_to_#{singular}
              @record = #{singular_name}.find(params[:id].to_i)
              @associated_record = #{many_class_name}.find(params[:#{singular}_#{many}_id].to_i)
              #{singular_name}.connection.execute("INSERT INTO #{join_table} (#{foreign_key}, #{association_foreign_key}) VALUES (\#{@record.id}, \#{@associated_record.id})")
              if request.xhr?
                render :update do |page|
                  page.insert_html(:top, '#{singular}_associated_records_list', :inline=>"<%= scaffold_habtm_association_line_item(@record, '#{singular}', @associated_record, '#{many}') %>")
                  page.remove("#{singular}_#{many}_id_\#{@associated_record.id}") unless #{reflection.klass.scaffold_use_auto_complete}
                  page["#{singular}_#{many}_id"].#{reflection.klass.scaffold_use_auto_complete ? "value = ''" : "selectedIndex = 0"}
                end
              else redirect_to(:action=>"edit#{suffix}", :id=>@record.id)
              end
            end
              
            def remove_#{many}_from_#{singular}
              @record = #{singular_name}.find(params[:id].to_i)
              @associated_record = #{many_class_name}.find(params[:#{singular}_#{many}_id].to_i)
              @record.#{many_name}.delete(@associated_record)
              if request.xhr?
                render(:update) do |page| 
                  page.remove("#{singular}_\#{@record.id}_#{many}_\#{@associated_record.id}")
                  page.insert_html(:bottom, '#{singular}_#{many}_id', "<option value='\#{@associated_record.id}' id='#{singular}_#{many}_id_\#{@associated_record.id}'>\#{@associated_record.scaffold_name}</option>") unless #{reflection.klass.scaffold_use_auto_complete}
                end
              else redirect_to(:action=>"edit#{suffix}", :id=>@record.id)
              end
            end
            
          end_eval
        else
          suffix = "_#{singular_name.underscore}_#{many_name}" 
          <<-"end_eval"
            def edit#{suffix}
              @singular_name = "#{singular_name}" 
              @many_name = "#{many_name.gsub('_',' ')}" 
              @singular_object = #{singular_name}.find(params[:id])
              @many_class = #{many_class_name}
              @items_to_remove = #{many_class_name}.find(:all, :conditions=>["#{many_class.primary_key} IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", params[:id].to_i], :order=>#{many_class_name}.scaffold_select_order).collect{|item| [item.scaffold_name, item.id]}
              unless #{many_class.scaffold_use_auto_complete}
                @items_to_add = #{many_class_name}.find(:all, :conditions=>["#{many_class.primary_key} NOT IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", params[:id].to_i], :order=>#{many_class_name}.scaffold_select_order).collect{|item| [item.scaffold_name, item.id]}
              end
              @scaffold_update_page = "update#{suffix}" 
              render_scaffold_template("habtm")
            end
            
            def update#{suffix}
              flash[:notice], success = begin
                singular_item = #{singular_name}.find(params[:id])
                if params[:add] && !params[:add].empty?
                  #{singular_name}.transaction do
                    multiple_select_ids(params[:add]).each do |associated_record_id|
                      #{singular_name}.connection.execute("INSERT INTO #{join_table} (#{foreign_key}, #{association_foreign_key}) VALUES (\#{singular_item.id}, \#{associated_record_id})")
                    end
                  end 
                end
                singular_item.#{many_name}.delete(#{many_class_name}.find(multiple_select_ids(params[:remove]))) if params[:remove] && !params[:remove].empty?
                ["Updated #{singular_name.underscore.humanize.downcase}'s #{many_name.humanize.downcase} successfully", true]
              rescue ::ActiveRecord::StatementInvalid
                ["Error updating #{singular_name.underscore.humanize.downcase}'s #{many_name.humanize.downcase}", false]
              end
              scaffold_habtm_redirect('#{suffix}', success)
            end
            
          end_eval
        end
        code << scaffold_habtm(many_class_name, singular_name, options.merge(:both_ways=>false)).to_s if options[:both_ways] && !reflection.options[:class_name]
        options[:generate] ? code : module_eval(code, __FILE__)
      end
      
      # Scaffolds all models in the Rails app, with all associations when called
      # with no arguments.  
      #
      # There are two ways to call it with arguments:
      # - Multiple string or symbol arguments specify models to be scaffolded.  No
      #   other models will be scaffolded (deprecated)
      # - One hash with the following symbols as keys:
      #   - :except => Array  # Don't scaffold these models
      #   - :only   => Array  # Only scaffold these models
      #   - :generate => true/false # Emit code generated instead of evaluating it
      #   - * (Everything else) => Hash 
      #     - Key is a symbol with the class name underscored.
      #     - Value is a hash of scaffold options.
      #     - To use a different singular name, use :model_id=>'singular_name' inside the value hash
      def scaffold_all_models(*models)
        models = parse_scaffold_all_models_options(*models)
        model_names = []
        scaffold_results = models.collect{|model, options| model_names << model.to_s; scaffold(model, options)}.compact
        code = <<-"end_eval"
          def index
            @models = #{model_names.inspect}
            render_scaffold_template("index")
          end
        end_eval
        scaffold_results.length > 0 ? scaffold_results.push(code).join("\n\n") : module_eval(code, __FILE__)
      end
      
      # Parse the arguments for scaffold_all_models.  Seperated so that it can
      # also be used in testing.
      def parse_scaffold_all_models_options(*models)
        options = models.pop if models.length > 0 && Hash === models[-1]
        generate = options.delete(:generate) if options
        except = options.delete(:except) if options
        only = options.delete(:only) if options
        except.collect!(&:to_s) if except
        only.collect!(&:to_s) if only
        models = ActiveRecord::Base.all_models if options || models.length == 0
        models.delete_if{|model| except.include?(model)} if except
        models.delete_if{|model| !only.include?(model)} if only
        models.collect do |model|
          scaffold_options = {:suffix=>true, :scaffold_all_models=>true, :generate=>generate, :habtm=>model.to_s.camelize.constantize.scaffold_habtm_reflections.collect{|r|r.name.to_s.singularize}}
          scaffold_options.merge!(options[model.to_sym]) if options && options.include?(model.to_sym)
          scaffold_model = scaffold_options.delete(:model_id) || model.to_sym
          [scaffold_model, scaffold_options]
        end
      end
    end
  end
end
