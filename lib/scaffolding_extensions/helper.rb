module ScaffoldingExtensions
  # Helper methods used by the scaffold templates
  module Helper
    private
      # Return a string containing associated objects and links (if they would work) to pages
      # to manage those objects.
      def scaffold_association_links
        klass = @scaffold_class
        return '' if @scaffold_class.scaffold_associations.empty?
        read_only = @scaffold_associations_readonly
        show_edit = read_only ? :show : :edit
        so = @scaffold_object
        soid = so.scaffold_id
        singular_name = @scaffold_options[:singular_name]
        content = '<h3 class="scaffold_associated_records_header">Associated Records</h3>'
        content << "<ul id='scaffolded_associations_#{singular_name}_#{soid}' class='#{klass.scaffold_association_list_class}'>\n"
        klass.scaffold_associations.each do |association| 
          next unless klass.scaffold_show_association_links?(association)
          class_name = klass.scaffold_associated_name(association)
          human_name = klass.scaffold_associated_human_name(association)
          content << "<li>"
          content << scaffold_check_link(human_name, read_only, "manage_#{class_name}") 
          content << "\n "
          case klass.scaffold_association_type(association)
            when :one
              associated_record = klass.scaffold_associated_objects(association, so, :session=>scaffold_session)
              content << " - #{scaffold_check_link(associated_record.scaffold_name, false, "#{show_edit}_#{class_name}", :id=>associated_record.scaffold_id) if associated_record}</li>\n"
              next
            when :edit
              content << scaffold_check_link('(associate)', true, "edit_#{singular_name}_#{association}", :id=>soid) unless read_only
            when :new
              unless read_only
                associated_params = {}
                klass.scaffold_new_associated_object_values(association, so).each{|key, value| associated_params["#{class_name}[#{key}]"] = value}
                content << scaffold_check_link('(create)', true, "new_#{class_name}", associated_params)
              end
          end
          if (records = klass.scaffold_associated_objects(association, so, :session=>scaffold_session)).length > 0
            content << "<ul>\n"
            records.each do |associated|
              content << "<li>#{scaffold_check_link(associated.scaffold_name, false, "#{show_edit}_#{class_name}", :id=>associated.scaffold_id)}</li>\n"
            end
            content << "</ul>\n"
          end
          content << "</li>\n"
        end
        content << "</ul>\n"
      end
      
      # Formats the records returned by scaffold autocompleting to be displayed,
      # should be an unordered list.  By default uses the scaffold_name and id of
      # the entries as the value.
      def scaffold_auto_complete_result(entries)
        return unless entries
        content = '<ul>'
        entries.collect{|entry| content << "<li>#{h(entry.scaffold_name_with_id)}</li>"}
        content << '</ul>'
        content
      end
      
      # Simple button with label text that submits a form to the given url, options are
      # passed to scaffold_form.
      def scaffold_button_to(text, url, options={})
        "#{scaffold_form(url, options)}\n<input type='submit' value='#{text}' />\n</form>"
      end
      
      # Simple button with label text that submits a form via Ajax to the given action,
      # options are passed to scaffold_form_remote_tag.
      def scaffold_button_to_remote(text, action, options)  
        "#{scaffold_form_remote_tag(action, options)}\n<input type='submit' value=#{text} />\n</form>"
      end
      
      # If scaffolding didn't create the action, return the empty string if blank is true
      # and the text itself if it is not.  Otherwise, returns a link to the action, options
      # are passed to scaffold_link.
      def scaffold_check_link(text, blank, action, options={})
        scaffolded_method?(action) ? scaffold_link(text, action, options) : (blank ? '' : h(text))
      end
      
      # Proc that formats the label and tag in a table row
      def scaffold_default_field_wrapper
        Proc.new{|label, tag| "<tr><td>#{label}</td><td>#{tag}</td></tr>\n"}
      end
      
      # Proc that formats each field row inside a table
      def scaffold_default_form_wrapper
        Proc.new{|rows|"<table class='#{@scaffold_class.scaffold_table_class(:form)}'><tbody>\n#{rows.join}</tbody></table>\n"}
      end
      
      # Forms an input field for the given field_type.
      #
      # The following field types are recognized:
      # * :text => textarea
      # * :boolean => select box with blank (NULL), True, and False
      # * :association => select box or autocompleteing text box for the association
      # * :submit, :password, :hidden, :file => input tag with matching type
      # * everything else => input tag with type text
      #
      # Options are converted to html attributes, with the following special options:
      # * :value => the value of the tag, which usually will be just an html attribute,
      #   but can be the html inside the textarea, or the choice of selection
      #   for one of the selection options
      # * :id => if :name is blank, it is also used for :name
      def scaffold_field_tag(field_type, options, object=nil, field=nil, record_name=nil, field_id=nil)
        options[:name] ||= options[:id] if options[:id]
        value = options[:value] || object.scaffold_value(field)
        case field_type
          when :text
            "<textarea #{scaffold_options_to_html(options)}>#{h value.to_s}</textarea>"
          when :boolean
            s = {value=>"selected='selected'"}
            "<select #{scaffold_options_to_html(options)}><option></option><option value='f' #{s[false]}>False</option><option value='t' #{s[true]}>True</option></select>"
          when :association
            klass = object.class
            if klass.scaffold_association_use_auto_complete(field)
              assocated_object = klass.scaffold_associated_objects(field, object, :session=>scaffold_session)
              options[:value] = assocated_object ? assocated_object.scaffold_name_with_id : ''
              scaffold_text_field_tag_with_auto_complete(options[:id], record_name, field, options)
            else
              s = {object.scaffold_value(field_id).to_i=>"selected='selected'"}
              associated_objects = klass.scaffold_association_find_objects(field, :session=>scaffold_session, :object=>object)
              "<select #{scaffold_options_to_html(options)}><option></option>#{associated_objects.collect{|ao| "<option value='#{i = ao.scaffold_id}' #{s[i]}>#{h ao.scaffold_name}</option>"}.join}</select>"
            end
          else
            options[:type] = :text
            case field_type
              when :submit, :password, :hidden, :file
                options[:size] ||= 30 if field_type == :password 
                options[:type] = field_type
              when :date, :integer, :float
                options[:size] ||= 10
              else
                options[:size] ||= 30
            end
            options[:value] ||= value
            "<input #{scaffold_options_to_html(options)} />"
        end
      end
      
      # Returns an opening form tag for the given url.  The following options are
      # used:
      # * :method => the method (:get or :post) to be used (default is :post)
      # * :attributes => extra html attributes for the form tag, as a string
      def scaffold_form(url, options={})
        meth = options.delete(:method) || :post
        "<form action='#{url}' method='#{meth}' #{options[:attributes]}>#{scaffold_token_tag if meth.to_s == 'post'}"
      end
      
      # "enctype='multipart/form-data'" if there is a file field in the form, otherwise
      # the empty string.
      def scaffold_form_enctype(column_names)
        klass = @scaffold_class
        column_names.each{|column_name| return "enctype='multipart/form-data'" if klass.scaffold_column_type(column_name) == :file }
        ''
      end
      
      # Returns html fragment containing autocompleting text or select boxes to add associated records
      # to the current record, and line items with buttons to remove associated records
      # from the current record.
      def scaffold_habtm_ajax_associations
        klass = @scaffold_class
        return '' unless klass.scaffold_habtm_with_ajax
        sn = @scaffold_options[:singular_name]
        so = @scaffold_object
        soid = so.scaffold_id
        content = "<div class='habtm_ajax_add_associations' id='#{sn}_habtm_ajax_add_associations'>"
        klass.scaffold_habtm_associations.reject{|association| !scaffolded_method?("add_#{association}_to_#{sn}")}.each do |association|
          content << "#{scaffold_form_remote_tag("add_#{association}_to_#{sn}", :id=>soid)}\n#{scaffold_habtm_ajax_tag("#{sn}_#{association}_id", so, sn, association)}\n<input name='commit' type='submit' value='Add #{klass.scaffold_associated_human_name(association).singularize}' /></form>\n"
        end
        content << "</div><div class='habtm_ajax_remove_associations' id='#{sn}_habtm_ajax_remove_associations'><ul id='#{sn}_associated_records_list'>"
        klass.scaffold_habtm_associations.reject{|association| !scaffolded_method?("remove_#{association}_from_#{sn}")}.each do |association|
          klass.scaffold_associated_objects(association, so, :session=>scaffold_session).each do |associated_record|
            content << scaffold_habtm_association_line_item(klass, association, @scaffold_object, associated_record)
          end
        end
        content << '</ul></div>'
        content
      end
      
      # Returns an autocompleting text box, or a select box displaying the records for the associated model that
      # are not already associated with this record.
      def scaffold_habtm_ajax_tag(id, record, model_name, association)
        klass = record.class
        if klass.scaffold_association_use_auto_complete(association)
          scaffold_text_field_tag_with_auto_complete(id, model_name, association)
        else
          scaffold_select_tag(id, klass.scaffold_unassociated_objects(association, record, :session=>scaffold_session))
        end
      end
      
      # Line item with button for removing the associated record from the current record
      def scaffold_habtm_association_line_item(klass, association, record, associated_record)
        name = klass.scaffold_name
        associated_suffix = klass.scaffold_associated_name(association)
        arid = associated_record.scaffold_id
        rid = record.scaffold_id
        content = "<li id='#{name}_#{rid}_#{association}_#{arid}'>\n"
        content << scaffold_check_link(klass.scaffold_associated_human_name(association), false, "manage_#{associated_suffix}")
        content << " - \n"
        content << scaffold_check_link(associated_record.scaffold_name, false, "edit_#{associated_suffix}", :id=>arid)
        content << "\n"
        content << scaffold_button_to_remote('Remove', "remove_#{association}_from_#{name}", :id=>rid, "#{name}_#{association}_id"=>arid)
        content << "\n</li>\n"
        content
      end
      
      # Script tag with javascript included inside a CDATA section
      def scaffold_javascript_tag(javascript)
        "<script type='text/javascript'>\n//<![CDATA[\n#{javascript}\n//]]>\n</script>"
      end
      
      # Label for the given html id with the content text
      def scaffold_label(id, text)
        "<label for='#{id}'>#{h text}</label>"
      end
      
      # 'a' tag with the content text.  action and options are passed to
      # scaffold_url to get the href.
      def scaffold_link(text, action, options={})
        "<a href='#{scaffold_url(action, options)}'>#{h text}</a>"
      end
      
      # Returns link to the scaffolded management page for the model if it was created by the scaffolding.
      def scaffold_manage_link
        manage = "manage#{@scaffold_suffix}"
        "<br />#{scaffold_link("Manage #{@scaffold_options[:plural_lc_human_name]}", manage)}" if scaffolded_method?(manage)
      end
      
      # A html fragment containing a paragraph stating there were errors for the @scaffold_object
      # and an unordered list with error messages for that object.  If there are no errors,
      # returns an empty string.
      def scaffold_model_error_messages
        return '' unless (errors = @scaffold_object.scaffold_error_messages).length > 0
        content = '<p>There were problems with the following fields:</p><ul>'
        errors.each{|msg| content << "<li>#{msg}</li>"}
        content << '</ul>'
        content
      end
      
      # An html fragment with all of the given fields for @scaffold_object, suitable for
      # inclusion in a form tag
      def scaffold_model_field_tags(fields)
        klass = @scaffold_class
        object = @scaffold_object
        record_name = @scaffold_options[:singular_name]
        field_wrapper = klass.scaffold_field_wrapper || scaffold_default_field_wrapper
        rows = fields.collect do |field|
          field_id = klass.scaffold_field_id(field)
          label = scaffold_label("#{record_name}_#{field_id}", klass.scaffold_column_name(field))
          options = klass.scaffold_column_options(field).merge(:name=>"#{record_name}[#{field_id}]", :id=>"#{record_name}_#{field_id}")
          field_tag = scaffold_field_tag(klass.scaffold_column_type(field), options, object, field, record_name, field_id)
          field_wrapper.call(label, field_tag)
        end
        (klass.scaffold_form_wrapper || scaffold_default_form_wrapper).call(rows)
      end
      
      # Returns an appropriate scaffolded data entry form for the model, with any related error messages.
      # If a block is given, it yields an empty string which should be modified with html to be added 
      # inside the form before the submit button.
      def scaffold_model_form(action, fields, &block)
        content = ''
        options = {}
        options[:id] = @scaffold_object.scaffold_id if action=='update'
        <<-END
        #{scaffold_model_error_messages}
        #{scaffold_form(scaffold_url("#{action}#{@scaffold_suffix}", options), :attributes=>scaffold_form_enctype(fields))}
        #{scaffold_model_field_tags(fields)}
        #{(yield content; content) if block_given?}
        <input type='submit' value="#{@scaffold_submit_value || "#{action.capitalize} #{@scaffold_options[:singular_lc_human_name]}"}" />
        </form>
        END
      end
      
      # Turns a hash of options into a string of html attributes, html escaping the values
      def scaffold_options_to_html(options)
        options.collect{|k,v| "#{k}=\"#{h v.to_s}\""}.join(' ')
      end
      
      # The suffix needed to params that should be lists.  The empty string by default.
      def scaffold_param_list_suffix
        ''
      end
      
      # A select tag with the provided name for the given collection of items. The options
      # will have the value of scaffold_id and the content of scaffold_name.  If multiple is
      # true, creates a multi-select box.
      def scaffold_select_tag(name, collection, multiple = false)
        "<select name='#{name}#{scaffold_param_list_suffix if multiple}' id='#{name}' #{"multiple='multiple'" if multiple}>#{'<option></option>' unless multiple}#{collection.collect{|obj| "<option value='#{i = obj.scaffold_id}' id='#{name}_#{i}'>#{h obj.scaffold_name}</option>"}.join("\n")}</select>"
      end
      
      # Text field with scaffold autocompleting.  The id is the html id, and the model name and association
      # are passed to scaffold_javascript_autocompleter.  The options are passed to scaffold_field_tag.
      def scaffold_text_field_tag_with_auto_complete(id, model_name, association = nil, options = {})
        content = ScaffoldingExtensions.auto_complete_css.dup
        content << scaffold_field_tag(:string, {:value=>'', :id=>id, :class=>'autocomplete'}.merge(options))
        content << scaffold_javascript_autocompleter(id, model_name, association)
        content
      end
      
      # A tag for a CSRF protection token.  The empty string by default as it
      # is framework dependent.
      def scaffold_token_tag
        ''
      end
  end
end
