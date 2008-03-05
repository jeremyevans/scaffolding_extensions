module ScaffoldingExtensions
  # Helper methods that require the Prototype Javascript library to work
  module PrototypeHelper
    JS_CHAR_FILTER = {'<'=>'\u003C', '>'=>'\u003E', '"'=>'\\"', "\n"=>'\n'}
    
    private
      # Javascript for adding an element to the top of the list of associated records,
      # and setting the autocomplete text box value to blank (if using autocompleting),
      # or removing the item from the select box and showing the blank record instead
      # (if not using autocompleting).
      def scaffold_add_habtm_element
        content = "new Insertion.Top('#{@records_list}', \"#{scaffold_javascript_character_filter(scaffold_habtm_association_line_item(@klass, @association, @record, @associated_record))}\");\n"
        if @auto_complete
          content << "$('#{@element_id}').value = '';\n"
        else
          content << "Element.remove('#{@element_id}_#{@associated_record.scaffold_id}');\n"
          content << "$('#{@element_id}').selectedIndex = 0;\n"
        end
        content
      end
      
      # A form tag with an onsubmit attribute that submits the form to the given url via Ajax
      def scaffold_form_remote_tag(url, options)
        u = scaffold_url(url, options)
        "<form method='post' action='#{u}' onsubmit=\"new Ajax.Request('#{u}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">\n#{scaffold_token_tag}\n"
      end
      
      # Javascript that takes the given id as the text box to autocomplete for, 
      # submitting the autocomplete request to scaffold_auto_complete_for_#{model_name}
      # (with the association if one is given), using the get method, and displaying values
      # in #{id}_scaffold_auto_complete.
      def scaffold_javascript_autocompleter(id, model_name, association)
        "\n<div class='auto_complete' id='#{id}_scaffold_auto_complete'></div>\n" <<
        scaffold_javascript_tag("var #{id}_auto_completer = new Ajax.Autocompleter('#{id}', '#{"#{id}_scaffold_auto_complete"}', '#{scaffold_url("scaffold_auto_complete_for_#{model_name}")}', {paramName:'id', method:'get'#{", parameters:'association=#{association}'" if association}})")
      end
      
      # Filters some html entities and replaces them with their javascript equivalents
      # suitable for use inside a javascript quoted string.
      def scaffold_javascript_character_filter(string)
        string.gsub(/[<>"\n]/){|x| JS_CHAR_FILTER[x]}
      end
      
      # Div with link inside that requests the associations html for the @scaffold_object
      # via Ajax and replaces the link with the html returned by the request
      def scaffold_load_associations_with_ajax_link
        soid = @scaffold_object.scaffold_id
        divid = "scaffold_ajax_content_#{soid}"
        "<div id='#{divid}'><a href='#{scaffold_url("edit#{@scaffold_suffix}", :id=>soid, :associations=>:show)}' onclick=\"new Ajax.Updater('#{divid}', '#{scaffold_url("associations#{@scaffold_suffix}", :id=>soid)}', {method:'get', asynchronous:true, evalScripts:true}); return false;\">Modify Associations</a></div>"
      end
      
      # Javascript that removes @remove_element_id from the page and inserts
      # an option into the appropriate select box (unless @auto_complete).
      def scaffold_remove_existing_habtm_element
        content = "Element.remove('#{@remove_element_id}');\n"
        content << "new Insertion.Bottom('#{@select_id}', \"\\u003Coption value='#{@select_value}' id='#{@select_id}_#{@select_value}'\\u003E#{@select_text}\\u003C/option\\u003E\");\n" unless @auto_complete
        content
      end
  end
end
