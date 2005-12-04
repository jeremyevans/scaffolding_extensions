# ScaffoldingExtensions
module ActiveRecord
  class Base
    @@scaffold_convert_text_to_string = false
    @@scaffold_table_classes = {:form=>'formtable', :list=>'sortable', :show=>'sortable'}
    @@scaffold_column_types = {'password'=>:password}
    @@scaffold_column_options = {}
    cattr_accessor :scaffold_convert_text_to_string, :scaffold_table_classes, :scaffold_column_types, :scaffold_column_options
    
    class << self
      attr_accessor :scaffold_select_order, :scaffold_include
      
      def merge_records(from, to)
        reflect_on_all_associations.each{|reflection| reflection_merge(reflection, from, to)}
        destroy(from)
      end
      
      def reflection_merge(reflection, from, to)
        foreign_key = reflection.options[:foreign_key] || table_name.classify.foreign_key
        sql = case reflection.macro
          when :has_one, :has_many
            "UPDATE #{reflection.klass.table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n" 
          when :has_and_belongs_to_many
            join_table = reflection.options[:join_table] || ( table_name < reflection.klass.table_name ? '#{table_name}_#{reflection.klass.table_name}' : '#{reflection.klass.table_name}_#{table_name}')
            "UPDATE #{join_table} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n" 
        end
        connection.update(sql)
      end
      
      def scaffold_fields
        @scaffold_fields ||= column_names
      end
      
      def scaffold_table_class(type)
        @scaffold_table_classes ||= @@scaffold_table_classes
        @scaffold_table_classes[type]
      end
      
      def scaffold_column_type(column_name)
        @scaffold_column_types ||= @@scaffold_column_types
        if @scaffold_column_types[column_name]
          @scaffold_column_types[column_name]
        elsif columns_hash.include?(column_name)
          type = columns_hash[column_name].type
          (@@scaffold_convert_text_to_string and type == :text) ? :string : type
        else :select
        end
      end
      
      def scaffold_column_options(column_name)
        @scaffold_column_options ||= @@scaffold_column_options
        @scaffold_column_options[column_name]
      end
    end
    
    def merge_into(record)
      raise ActiveRecordError if record.class != self.class
      self.class.reflect_on_all_associations.each{|reflection| self.class.reflection_merge(reflection, id, record.id)}
      destroy
      record.reload
    end
    
    def scaffold_name
      self[:name] or id
    end
  end
end

module ActionView
  module Helpers
    module ActiveRecordHelper
      def all_input_tags(record, record_name, options)
        input_block = options[:input_block] || default_input_block
        rows = record.class.scaffold_fields.collect do |field|
          reflection = record.class.reflect_on_association(field.to_sym)
          if reflection
            input_block.call(record_name, reflection) 
          else
            input_block.call(record_name, record.column_for_attribute(field))
          end
        end
        "\n<table class='#{@scaffold_class.scaffold_table_class :form}'><tbody>\n#{rows.join}</tbody></table><br />"
      end
    
      def default_input_block
        Proc.new do |record, column| 
          if column.class.name =~ /Reflection/
            if column.macro == :belongs_to
              "<tr><td>#{column.klass.name}:</td><td>#{input(record, column.name)}</td></tr>\n"
            end
          else
            "<tr><td>#{column.human_name}:</td><td>#{input(record, column.name)}</td></tr>\n"
          end  
        end
      end
    end

    class InstanceTag      
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
          when :select
            to_association_select_tag(options)
        end
      end
    
      def to_boolean_select_tag(options = {})
        options = options.stringify_keys
        add_default_name_and_id(options)
        "<select#{tag_options(options)}><option value=''>&nbsp;</option><option value='f'#{selected(!value)}>False</option><option value='t'#{selected(value)}>True</option></select>"
      end
      
      def selected(value)
        value ? " selected='selected'" : '' 
      end
    
      def to_date_select_tag(options = {})
        to_input_field_tag('text', {'size'=>'10'}.merge(options))
      end
      
      def to_datetime_select_tag(options = {})
        to_input_field_tag('text', options)
      end
    
      def to_text_area_tag(options = {})
        options = DEFAULT_TEXT_AREA_OPTIONS.merge(options.stringify_keys)
        add_default_name_and_id(options)
        content_tag("textarea", html_escape(value), options)
      end
    
      def column_type
        object.class.scaffold_column_type(@method_name)
      end
        
      def to_association_select_tag(options)
        reflection = object.class.reflect_on_association @method_name.to_sym
        @method_name = reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key
        alias_name = reflection.klass.table_name
        conditions = eval("\"#{reflection.options[:conditions]}\"") if reflection.options[:conditions]
        items = reflection.klass.find(:all, :order => reflection.klass.scaffold_select_order, :conditions=>conditions, :include=>reflection.klass.scaffold_include)
        items.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if reflection.klass.scaffold_include
        to_collection_select_tag(items, :id, :scaffold_name, {:include_blank=>true}.merge(options), {})
      end
    end
  end
end

module ActionController
  class Base
    @@scaffold_template_dir = "#{File.dirname(__FILE__)}/../scaffolds"
    @@default_scaffold_methods = [:manage, :show, :destroy, :edit, :new, :search, :merge]
    cattr_accessor = :scaffold_template_dir, :default_scaffold_methods
    
    class << self
      def scaffold_template_dir
        @scaffold_template_dir ||= @@scaffold_template_dir
      end
      
      def default_scaffold_methods
        @default_scaffold_methods ||= @@default_scaffold_methods
      end
    end
    
    private
    def render_habtm_scaffold(action = "habtm")
      if template_exists?("\#{self.class.controller_path}/\#{action}")
        render_action(action)
      else
        render(:file=>scaffold_path(action), :layout=>self.active_layout)
      end
    end
  
    def scaffold_path(template_name)
      File.join(self.class.scaffold_template_dir, template_name+'.rhtml')
    end
  
    def multiple_select_ids(arr)
      arr.collect{|x| x.to_i}.delete_if{|x| x == 0}
    end
    
    def scaffold_search_add_condition(conditions, record, field)
      column = record.column_for_attribute(field)
      if column and column.klass == String
        if record.send(field).length > 0
          conditions[0] << "#{record.class.table_name}.#{field} ILIKE ?"
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

  module Scaffolding
    module ClassMethods
      def scaffold(model_id, options = {})
        options.assert_valid_keys(:class_name, :suffix, :except, :only, :habtm)
      
        singular_name = model_id.to_s
        class_name    = options[:class_name] || singular_name.camelize
        plural_name   = singular_name.pluralize
        suffix        = options[:suffix] ? "_#{singular_name}" : ""
        add_methods = (options[:only] || self.default_scaffold_methods)
        add_methods -= options[:except] if options[:except]
        
        habtm = case options[:habtm]
          when Array then options[:habtm]
          when Symbol then [options[:habtm]]
          else []
        end
        habtm.each {|habtm_class| scaffold_habtm(model_id, habtm_class, false)}
        
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
        
        if add_methods.include?(:show) or add_methods.include?(:destory) or add_methods.include?(:edit)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def list#{suffix}
              @scaffold_action ||= 'edit'
              @#{plural_name} = #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
              @#{plural_name}.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if #{class_name}.scaffold_include
              render#{suffix}_scaffold "list#{suffix}"
            end
          end_eval
        end
        
        if add_methods.include?(:show)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def show#{suffix}
              if @params[:id]
                @#{singular_name} = #{class_name}.find(@params[:id], :include=>#{class_name}.scaffold_include)
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
              if @params[:id]
                #{class_name}.find(@params[:id]).destroy
                redirect_to :action => "manage#{suffix}"
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
              if @params[:id]
                @#{singular_name} = #{class_name}.find(@params[:id])
                render#{suffix}_scaffold
              else
                @scaffold_action = 'edit'
                list#{suffix}
              end
            end
            
            def update#{suffix}
              @#{singular_name} = #{class_name}.find(@params[:id])
              @#{singular_name}.attributes = @params[:#{singular_name}]
        
              if @#{singular_name}.save
                flash[:notice] = "#{class_name} was successfully updated"
                redirect_to :action => "show#{suffix}", :id => @#{singular_name}.id.to_s
              else
                render#{suffix}_scaffold('edit')
              end
            end
          end_eval
        end
        
        if add_methods.include?(:new)
          module_eval <<-"end_eval", __FILE__, __LINE__
            def new#{suffix}
              @#{singular_name} = #{class_name}.new
              render#{suffix}_scaffold
            end
            
            def create#{suffix}
              @#{singular_name} = #{class_name}.new(@params[:#{singular_name}])
              if @#{singular_name}.save
                flash[:notice] = "#{class_name} was successfully created"
                redirect_to :action => "show#{suffix}", :id => @#{singular_name}.id
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
                reflection ? (reflection.options[:foreign_key] || singular_class.table_name.classify.foreign_key) : field
              end
              render#{suffix}_scaffold('search#{suffix}')
            end
            
            def results#{suffix}
              record = #{class_name}.new(@params["#{singular_name}"])
              conditions = [[]]
              includes = []
              if params[:#{singular_name}]
                #{class_name}.scaffold_fields.each do |field|
                  reflection = #{class_name}.reflect_on_association(field.to_sym)
                  if reflection
                    includes << field.to_sym
                    field = reflection.options[:foreign_key].to_s
                  end
                  next if (@params['null'] and @params['null'].include?(field)) or (@params['notnull'] and @params['notnull'].include?(field))
                  scaffold_search_add_condition(conditions, record, field) if @params[:#{singular_name}][field] and @params[:#{singular_name}][field].length > 0
                end
              end
              @params['null'].each {|field| conditions[0] << field + ' IS NULL' } if @params['null']
              @params['notnull'].each {|field| conditions[0] << field + ' IS NOT NULL' } if @params['notnull']
              conditions[0] = conditions[0].join(' AND ')
              conditions[0] = '1=1' if conditions[0].length == 0
              @#{plural_name} = #{class_name}.find(:all, :conditions=>conditions, :include=>includes)
              render#{suffix}_scaffold('listtable#{suffix}')
            end
          end_eval
        end
      
      if add_methods.include?(:merge)
        module_eval <<-"end_eval", __FILE__, __LINE__
          def merge#{suffix}
            @#{plural_name} = #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order, :include=>#{class_name}.scaffold_include)
            @#{plural_name}.sort! {|x,y| x.scaffold_name <=> y.scaffold_name} if #{class_name}.scaffold_include
            render#{suffix}_scaffold('merge#{suffix}')
          end
    
          def merge_update#{suffix}
            #{class_name}.merge_records(params[:from], params[:to])
            redirect_to :action=>'merge#{suffix}'
          end
        end_eval
      end
        
        module_eval <<-"end_eval", __FILE__, __LINE__
          private
            def render#{suffix}_scaffold(action=nil)
              action ||= caller_method_name(caller)
              @scaffold_class = #{class_name}
              @scaffold_singular_name, @scaffold_plural_name = "#{singular_name}", "#{plural_name}"
              @scaffold_methods = #{add_methods.inspect}
              @scaffold_suffix = "#{suffix}"
              @scaffold_habtms = #{habtm.inspect}
              add_instance_variables_to_assigns
              if template_exists?("\#{self.class.controller_path}/\#{action}")
                render_action(action)
              else
                render(:file=>scaffold_path(action.sub(/#{suffix}$/, "")), :layout=>self.active_layout)
              end
            end
            
            def caller_method_name(caller)
              caller.first.scan(/`(.*)'/).first.first # ' ruby-mode
            end
        end_eval
      end
      
      def scaffold_habtm(singular, many, both_ways = true)
        singular_class, many_class = eval(singular.to_s.camelize), eval(many.to_s.camelize)
        singular_name,  = singular_class.name
        many_class_name = many_class.name
        many_name = many_class.name.pluralize.underscore
        reflection = singular_class.reflect_on_association(many_name.to_sym)
        return false if reflection.nil? or reflection.macro != :has_and_belongs_to_many
        foreign_key = reflection.options[:foreign_key] || singular_class.table_name.classify.foreign_key
        association_foreign_key = reflection.options[:association_foreign_key] || many_class.table_name.classify.foreign_key
        join_table = reflection.options[:join_table] || ( singular_name < many_class_name ? '#{singular_name}_#{many_class_name}' : '#{many_class_name}_#{singular_name}')
        suffix = "_#{singular_name.underscore}_#{many_name}" 
        module_eval <<-"end_eval", __FILE__, __LINE__
          def edit#{suffix}
            @singular_name = "#{singular_name}" 
            @many_name = "#{many_name.gsub('_',' ')}" 
            @singular_object = #{singular_name}.find(@params['id'])
            @items_to_remove = #{many_class_name}.find(:all, :conditions=>["id IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", @params['id'].to_i], :order=>"#{many_class.scaffold_select_order}").collect{|item| [item.scaffold_name, item.id]}
            @items_to_add = #{many_class_name}.find(:all, :conditions=>["id NOT IN (SELECT #{association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{foreign_key} = ?)", @params['id'].to_i], :order=>"#{many_class.scaffold_select_order}").collect{|item| [item.scaffold_name, item.id]}
            @scaffold_update_page = "update#{suffix}" 
            render_habtm_scaffold
          end
    
          def update#{suffix}
            flash['notice'] = begin
              singular_item = #{singular_name}.find(@params['id'])
              singular_item.#{many_name}.push(#{many_class_name}.find(multiple_select_ids(@params['add']))) if @params['add']
              singular_item.#{many_name}.delete(#{many_class_name}.find(multiple_select_ids(@params['remove']))) if @params['remove']
              "Updated #{singular_name}'s #{many_name} successfully" 
            rescue ::ActiveRecord::StatementInvalid
              "Error updating #{singular_name}'s #{many_name}" 
            end
            redirect_to(:action=>"edit#{suffix}", :id=>@params['id'])
          end
        end_eval
        both_ways ? scaffold_habtm(many_class, singular_class, false) : true
      end
    end
  end
end