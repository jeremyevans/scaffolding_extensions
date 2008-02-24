#!/usr/bin/env ruby
require 'rubygems'
require 'test/unit'
require 'hpricot'
require 'set'
require 'open-uri'
require 'net/http'

ORMS = ['active_record', 'data_mapper']
FRAMEWORKS = {'rails'=>7979, 'ramaze'=>7978, 'camping'=>7977}

ARGV.each do |arg|
  raise ArgumentError, 'Not a valid ORM or framework' unless ORMS.include?(arg) || FRAMEWORKS.include?(arg)
  ORMS.replace([arg]) if ORMS.include?(arg)
  FRAMEWORKS.replace({arg=>FRAMEWORKS[arg]}) if FRAMEWORKS.include?(arg)
end

class ScaffoldingExtensionsTest < Test::Unit::TestCase
  HOST='localhost'
  FIELD_NAMES={'employee'=>%w'Active Comment Name Password Position', 'position'=>%w'Name', 'group'=>%w'Name'}
  FIELDS={'employee'=>%w'active comment name password position_id', 'position'=>%w'name', 'group'=>%w'name'}
  ACTION_MAP={'delete'=>'destroy', 'edit'=>'edit', 'show'=>'show'}

  def self.test_all_frameworks_and_dbs
    instance_methods.sort.grep(/\Atest_\d\d/).each do |method|
      meth = :"_#{method}"
      alias_method meth, method
      define_method(method) do
        FRAMEWORKS.values.sort.each do |port|
          ORMS.each do |root|
            send(meth, port, "/#{root}") rescue (puts "Error! port:#{port} orm:#{root}"; raise)
          end
        end
      end
    end
  end

  def assert_se_path(port, root, path, location)
    assert_equal "//#{HOST}:#{port}#{root}#{path}", location.sub('http:', '')
  end

  def page(port, path)
    Hpricot(open("http://#{HOST}:#{port}#{path}"))
  end
  
  def post(port, path, params)
    req = Net::HTTP::Post.new(path)
    req.set_form_data(params)
    Net::HTTP.new(HOST, port).start {|http| http.request(req) }
  end

  def test_00_clear_db(port, root)
    %w'employee position group'.each do |model|
      p = page(port, "#{root}/show_#{model}")
      opts = p/:option
      opts.shift
      opts.each do |opt| 
        res = post(port, "#{root}/destroy_#{model}", :id=>opt[:value])
        assert_se_path port, root, "/delete_#{model}", res['Location']
      end
    end
  end

  def test_01_no_objects(port, root)
     p = page(port, root)    
     assert_equal 'Scaffolding Extensions - Manage Models', p.at(:title).inner_html
     assert_equal 'Manage Models', p.at(:h1).inner_html
     assert_equal 1, (p/:ul).length
     assert_equal 3, (p/:ul/:li).length
     assert_equal %w'Employee Group Position', (p/:a).collect{|x| x.inner_html}
     (p/:a).each do |el|
       root1 = el[:href]
       p1 = page(port, root1)
       sn = el.inner_html.downcase
       assert_equal "Scaffolding Extensions - Manage #{sn}s", p1.at(:title).inner_html
       assert_equal "Manage #{sn}s", p1.at(:h1).inner_html
       assert_equal 1, (p1/:ul).length
       assert_equal 7, (p1/:ul/:li).length
       assert_equal 8, (p1/:a).length
       assert_equal 7, (p1/:ul/:a).length
       assert_equal 'Manage Models', (p1/:a).last.inner_html
       assert_match %r{\A#{root}(/index)?\z}, (p1/:a).last[:href]
       (p1/:ul/:a).each do |el1|
         manage_re = %r{\A(Browse|Create|Delete|Edit|Merge|Search|Show) #{sn}s?\z}
         assert_match manage_re, el1.inner_html
         manage_re = %r{\A#{root}/(browse|new|delete|edit|merge|search|show)_#{sn}\z}
         assert_match manage_re, el1[:href]
         page_type = manage_re.match(el1[:href])[1]
         p2 = page(port, el1[:href])
         case page_type
           when 'browse'
             assert_equal "Scaffolding Extensions - Listing #{sn}s", p2.at(:title).inner_html
             assert_equal "Listing #{sn}s", p2.at(:h1).inner_html
             assert_equal FIELD_NAMES[sn]+%w'Show Edit Delete', (p2/:th).collect{|x| x.inner_html}
             assert_equal 0, (p2/:td).length
             assert_equal 1, (p2/:a).length
             assert_equal root1, p2.at(:a)[:href]
           when 'new'
             assert_equal "Scaffolding Extensions - Create new #{sn}", p2.at(:title).inner_html
             assert_equal "Create new #{sn}", p2.at(:h1).inner_html
             assert_equal "#{root}/create_#{sn}", p2.at(:form)[:action]
             assert_equal "post", p2.at(:form)[:method]
             assert_equal "Create #{sn}", p2.at("form > input")[:value]
             assert_equal "submit", p2.at("form > input")[:type]
             assert_equal FIELD_NAMES[sn], (p2/:label).collect{|x| x.inner_html}
             assert_equal FIELDS[sn].collect{|x| "#{sn}_#{x}"}, (p2/:label).collect{|x| x[:for]}
             assert_equal Set.new(FIELDS[sn].collect{|x| "#{sn}_#{x}"}), Set.new((p2/('td input, td select, td textarea')).collect{|x| x[:id]})
             assert_equal Set.new(FIELDS[sn].collect{|x| "#{sn}[#{x}]"}), Set.new((p2/('td input, td select, td textarea')).collect{|x| x[:name]})
           when 'delete', 'show', 'edit'
             assert_equal "Scaffolding Extensions - Choose #{sn} to #{ACTION_MAP[page_type]}", p2.at(:title).inner_html
             assert_equal "Choose #{sn} to #{ACTION_MAP[page_type]}", p2.at(:h1).inner_html
             assert_equal "#{root}/#{ACTION_MAP[page_type]}_#{sn}", p2.at(:form)[:action]
             assert_equal (page_type == 'delete' ? "post" : 'get'), p2.at(:form)[:method]
             assert_equal "#{ACTION_MAP[page_type].capitalize} #{sn}", p2.at(:input)[:value]
             assert_equal "submit", p2.at(:input)[:type]
             assert_equal "id", p2.at(:select)[:name]
             assert_equal 1, (p2/:option).length
             assert_equal nil, p2.at(:option)[:value]
             assert_equal '', p2.at(:option).inner_html
           when 'merge'
             assert_equal "Scaffolding Extensions - Merge two #{sn}s", p2.at(:title).inner_html
             assert_equal "Merge two #{sn}s", p2.at(:h1).inner_html
             assert_equal "#{root}/merge_update_#{sn}", p2.at(:form)[:action]
             assert_equal "post", p2.at(:form)[:method]
             assert_equal 2, (p2/:select).length
             assert_equal 'from', (p2/:select).first[:name]
             assert_equal 'to', (p2/:select).last[:name]
             assert_equal 2, (p2/:option).length
             assert_equal nil, (p2/:option).first[:value]
             assert_equal nil, (p2/:option).last[:value]
             assert_equal '', (p2/:option).first.inner_html
             assert_equal '', (p2/:option).last.inner_html
             assert_equal "Merge #{sn}s", p2.at(:input)[:value]
             assert_equal "submit", p2.at(:input)[:type]
           when 'search'
             assert_equal "Scaffolding Extensions - Search #{sn}s", p2.at(:title).inner_html
             assert_equal "Search #{sn}s", p2.at(:h1).inner_html
             assert_equal "#{root}/results_#{sn}", p2.at(:form)[:action]
             assert_equal "post", p2.at(:form)[:method]
             assert_equal "Search #{sn}s", p2.at("form > input")[:value]
             assert_equal "submit", p2.at("form > input")[:type]
             assert_equal FIELD_NAMES[sn] + ['Null Fields', 'Not Null Fields'], (p2/:label).collect{|x| x.inner_html}
             assert_equal FIELDS[sn].collect{|x| "#{sn}_#{x}"} + %w'null notnull', (p2/:label).collect{|x| x[:for]}
             assert_equal Set.new(FIELDS[sn].collect{|x| "#{sn}_#{x}"} + %w'null notnull'), Set.new((p2/('td input, td select, td textarea')).collect{|x| x[:id]})
             assert_equal Set.new(FIELDS[sn].collect{|x| "#{sn}[#{x}]"} + %w'null notnull'), Set.new((p2/('td input, td select, td textarea')).collect{|x| x[:name].sub('[]', '')})
             assert_equal FIELD_NAMES[sn], (p2/'select#null option').collect{|x| x.inner_html}
             assert_equal FIELD_NAMES[sn], (p2/'select#notnull option').collect{|x| x.inner_html}
             assert_equal FIELDS[sn], (p2/'select#null option').collect{|x| x[:value]}
             assert_equal FIELDS[sn], (p2/'select#notnull option').collect{|x| x[:value]}
             assert_equal 'multiple', p2.at('select#null')[:multiple]
             assert_equal 'multiple', p2.at('select#notnull')[:multiple]
         end
       end
     end
  end
  
  def test_02_simple_object(port, root)
    %w'position group'.each do |model|
      name = "Test#{model}"
      res = post(port, "#{root}/create_#{model}", "#{model}[name]"=>name)
      assert_se_path port, root, "/new_#{model}", res['Location']
      
      %w'browse results'.each do |action|
        p = page(port, "#{root}/#{action}_#{model}")
        assert_equal 4, (p/:td).length
        assert_equal 3, (p/:form).length
        assert_equal name, (p/:td).first.inner_html
        assert_match %r|#{root}/show_#{model}/\d+|, (p/:form)[0][:action]
        assert_match %r|#{root}/edit_#{model}/\d+|, (p/:form)[1][:action]
        assert_match %r|#{root}/destroy_#{model}/\d+|, (p/:form)[2][:action]
        assert_equal 'get', (p/:form)[0][:method]
        assert_equal 'get', (p/:form)[1][:method]
        assert_equal 'post', (p/:form)[2][:method]
        assert_equal 'Show', (p/:input)[0][:value]
        assert_equal 'Edit', (p/:input)[1][:value]
        assert_equal 'Delete', (p/:input)[2][:value]
      end
  
      %w'show edit delete'.each do |action|
        p = page(port, "#{root}/#{action}_#{model}")
        assert_equal 2, (p/:option).length
        assert_match /\d+/, (p/:option).last[:value]
        assert_equal name, (p/:option).last.inner_html
      end
  
      p = page(port, "#{root}/merge_#{model}")
      assert_equal 4, (p/:option).length
      assert_match /\d+/, (p/:option)[1][:value]
      i = (p/:option)[1][:value]
      assert_equal i, (p/:option)[3][:value]
      assert_equal name, (p/:option)[1].inner_html
      assert_equal name, (p/:option)[3].inner_html
  
      p = page(port, "#{root}/show_#{model}/#{i}")
      assert_equal "#{root}/edit_#{model}/#{i}", (p/:a)[0][:href]
      assert_equal 'Edit', (p/:a)[0].inner_html
      assert_equal 'Attribute', (p/:th)[0].inner_html
      assert_equal 'Value', (p/:th)[1].inner_html
      assert_equal 'Name', (p/:td)[0].inner_html
      assert_equal name, (p/:td)[1].inner_html
      assert_equal 'Associated Records', p.at(:h3).inner_html
      assert_equal 'scaffold_associated_records_header', p.at(:h3)[:class]
      assert_equal "scaffolded_associations_#{model}_#{i}", p.at(:ul)[:id]
      assert_equal 1, (p/:li).length
      assert_equal "#{root}/manage_employee", (p/:a)[1][:href]
      assert_equal "Employees", (p/:a)[1].inner_html
  
      p = page(port, "#{root}/edit_#{model}/#{i}")
      assert_equal "#{root}/update_#{model}/#{i}", p.at(:form)[:action]
      assert_equal "post", p.at(:form)[:method]
      assert_equal "#{model}[name]", (p/:input)[0][:name]
      assert_equal name, (p/:input)[0][:value]
      assert_equal 'text', (p/:input)[0][:type]
      assert_equal "Update #{model}", (p/:input)[1][:value]
      assert_equal 'submit', (p/:input)[1][:type]
      assert_equal 'Associated Records', p.at(:h3).inner_html
      assert_equal 'scaffold_associated_records_header', p.at(:h3)[:class]
      assert_equal "scaffolded_associations_#{model}_#{i}", p.at(:ul)[:id]
      assert_equal 1, (p/:li).length
      assert_equal "#{root}/manage_employee", (p/:a)[0][:href]
      assert_equal "Employees", (p/:a)[0].inner_html
      if model == 'position' 
        assert_equal "#{root}/new_employee?employee%5Bposition_id%5D=#{i}", (p/:a)[1][:href]
        assert_equal '(create)', (p/:a)[1].inner_html
      else
        assert_equal "#{root}/edit_#{model}_employees/#{i}", (p/:a)[1][:href]
        assert_equal '(associate)', (p/:a)[1].inner_html
      end
    end
    
    p = page(port, "#{root}/show_position")
    i = (p/:option).last[:value]
    p = page(port, "#{root}/show_position/#{i}")
    # Check edit link from show page works
    p = page(port, (p/:a).first[:href])
    # Check create employee link on edit position page sets position for employee
    p = page(port, (p/:a)[1][:href])
    assert_equal 3, (p/'select#employee_active option').length
    assert_equal [nil, 'f', 't'], (p/'select#employee_active option').collect{|x| x[:value]}
    assert_equal 'employee_comment', p.at(:textarea)[:id]
    assert_equal 'text', p.at('input#employee_name')[:type]
    assert_equal 'text', p.at('input#employee_password')[:type]
    assert_equal i, (p/'select#employee_position_id option').last[:value]
    assert_equal 'selected', (p/'select#employee_position_id option').last[:selected]
  end

  def test_03_complex_object_and_relationships(port, root)
    p = page(port, "#{root}/show_position")
    position_id = (p/:option).last[:value]
    p = page(port, "#{root}/show_group")
    group_id = (p/:option).last[:value]
    
    res = post(port, "#{root}/create_employee", "employee[name]"=>"Testemployee", 'employee[active]'=>'t', 'employee[comment]'=>'Comment', 'employee[password]'=>'password', 'employee[position_id]'=>position_id)
    assert_se_path port, root, "/new_employee", res['Location']
    
    p = page(port, "#{root}/show_employee")
    i = (p/:option).last[:value]
    p = page(port, "#{root}/show_employee/#{i}")
    assert_equal %w'Active true Comment Comment Name Testemployee Password password Position Testposition', (p/:td).collect{|x| x.inner_html}
    assert_equal 2, (p/:li).length
    assert_equal 5, (p/:a).length
    assert_equal 'Groups', (p/:a)[1].inner_html
    assert_equal 'Position', (p/:a)[2].inner_html
    assert_equal 'Testposition', (p/:a)[3].inner_html
    assert_equal "#{root}/manage_group", (p/:a)[1][:href]
    assert_equal "#{root}/manage_position", (p/:a)[2][:href]
    assert_equal "#{root}/show_position/#{position_id}", (p/:a)[3][:href]

    # Edit page
    p1 = p = page(port, (p/:a)[0][:href])
    assert_equal 3, (p/'select#employee_active option').length
    assert_equal [nil, 'f', 't'], (p/'select#employee_active option').collect{|x| x[:value]}
    assert_equal nil, (p/'select#employee_active option')[1][:selected]
    assert_equal 'selected', (p/'select#employee_active option')[2][:selected]
    assert_equal 'employee_comment', p.at(:textarea)[:id]
    assert_equal 'Comment', p.at(:textarea).inner_html
    assert_equal 'text', p.at('input#employee_name')[:type]
    assert_equal 'Testemployee', p.at('input#employee_name')[:value]
    assert_equal 'text', p.at('input#employee_password')[:type]
    assert_equal 'password', p.at('input#employee_password')[:value]
    assert_equal position_id, (p/'select#employee_position_id option').last[:value]
    assert_equal 'selected', (p/'select#employee_position_id option').last[:selected]
    assert_equal 'Groups', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Position', (p/:a)[2].inner_html
    assert_equal 'Testposition', (p/:a)[3].inner_html
    assert_equal "#{root}/manage_group", (p/:a)[0][:href]
    assert_equal "#{root}/edit_employee_groups/#{i}", (p/:a)[1][:href]
    assert_equal "#{root}/manage_position", (p/:a)[2][:href]
    assert_equal "#{root}/edit_position/#{position_id}", (p/:a)[3][:href]

    # Edit employee's groups page
    p = page(port, (p/:a)[1][:href])
    assert_equal "Update Testemployee's groups", p.at(:h1).inner_html
    assert_equal "#{root}/update_employee_groups/#{i}", p.at(:form)[:action]
    assert_equal "post", p.at(:form)[:method]
    assert_equal 'Add these groups', p.at(:h4).inner_html
    assert_equal 'add', p.at(:select)[:id]
    assert_equal 'add', p.at(:select)[:name].sub('[]', '')
    assert_equal 'multiple', p.at(:select)[:multiple]
    assert_equal group_id, p.at(:option)[:value]
    assert_equal "add_#{group_id}", p.at(:option)[:id]
    assert_equal 'Testgroup', p.at(:option).inner_html
    assert_equal 'submit', p.at(:input)[:type]
    assert_equal "Update Testemployee's groups", p.at(:input)[:value]
    assert_equal 'Edit Testemployee', p.at(:a).inner_html
    assert_equal "#{root}/edit_employee/#{i}", p.at(:a)[:href]

    # Update the groups
    res = post(port, p.at(:form)[:action], p.at(:select)[:name]=>p.at(:option)[:value])
    assert_se_path port, root, "/edit_employee_groups/#{i}", res['Location']

    # Recheck the habtm page
    p = page(port, (p1/:a)[1][:href])
    assert_equal 'Remove these groups', p.at(:h4).inner_html
    assert_equal 'remove', p.at(:select)[:id]
    assert_equal 'remove', p.at(:select)[:name].sub('[]', '')
    assert_equal 'multiple', p.at(:select)[:multiple]
    assert_equal group_id, p.at(:option)[:value]
    assert_equal "remove_#{group_id}", p.at(:option)[:id]
    assert_equal 'Testgroup', p.at(:option).inner_html
    assert_equal 'submit', p.at(:input)[:type]
    assert_equal "Update Testemployee's groups", p.at(:input)[:value]

    # Recheck employee edit page
    p = page(port, p.at(:a)[:href])
    assert_equal 'Groups', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Testgroup', (p/:a)[2].inner_html
    assert_equal 'Position', (p/:a)[3].inner_html
    assert_equal 'Testposition', (p/:a)[4].inner_html
    assert_equal "#{root}/manage_group", (p/:a)[0][:href]
    assert_equal "#{root}/edit_employee_groups/#{i}", (p/:a)[1][:href]
    assert_equal "#{root}/edit_group/#{group_id}", (p/:a)[2][:href]
    assert_equal "#{root}/manage_position", (p/:a)[3][:href]
    assert_equal "#{root}/edit_position/#{position_id}", (p/:a)[4][:href]

    # Check working link to group page
    p = page(port, (p/:a)[2][:href])
    assert_equal 'Employees', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Testemployee', (p/:a)[2].inner_html
    assert_equal "#{root}/manage_employee", (p/:a)[0][:href]
    assert_equal "#{root}/edit_group_employees/#{group_id}", (p/:a)[1][:href]
    assert_equal "#{root}/edit_employee/#{i}", (p/:a)[2][:href]

    # Edit group's employees page
    p = page(port, (p/:a)[1][:href])
    assert_equal "Update Testgroup's employees", p.at(:h1).inner_html
    assert_equal "#{root}/update_group_employees/#{group_id}", p.at(:form)[:action]
    assert_equal "post", p.at(:form)[:method]
    assert_equal 'Remove these employees', p.at(:h4).inner_html
    assert_equal 'remove', p.at(:select)[:id]
    assert_equal 'remove', p.at(:select)[:name].sub('[]', '')
    assert_equal 'multiple', p.at(:select)[:multiple]
    assert_equal i, p.at(:option)[:value]
    assert_equal "remove_#{i}", p.at(:option)[:id]
    assert_equal 'Testemployee', p.at(:option).inner_html
    assert_equal 'submit', p.at(:input)[:type]
    assert_equal "Update Testgroup's employees", p.at(:input)[:value]

    # Update the employees
    res = post(port, p.at(:form)[:action], p.at(:select)[:name]=>p.at(:option)[:value])
    assert_se_path port, root, "/edit_group_employees/#{group_id}", res['Location']

    # Recheck the edit group page
    p = page(port, p.at(:a)[:href])
    assert_equal 'Employees', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Manage groups', (p/:a)[2].inner_html
    assert_equal "#{root}/manage_employee", (p/:a)[0][:href]
    assert_equal "#{root}/edit_group_employees/#{group_id}", (p/:a)[1][:href]
  end

  def test_04_browse_search(port, root)
    %w'position group employee'.each do |model|
      res = post(port, "#{root}/create_#{model}", "#{model}[name]"=>"Best#{model}")
      assert_se_path port, root, "/new_#{model}", res['Location']
      
      #Get ids for both objects
      p = page(port, "#{root}/show_#{model}")
      assert_equal 3, (p/:option).length
      assert_match /\d+/, (p/:option)[1][:value]
      assert_equal "Best#{model}", (p/:option)[1].inner_html
      assert_match /\d+/, (p/:option)[2][:value]
      assert_equal "Test#{model}", (p/:option)[2].inner_html
      b = (p/:option)[1][:value]
      t = (p/:option)[2][:value]

      # Check first object shows up on first browse page
      p = page(port, "#{root}/browse_#{model}")
      assert_match %r|#{root}/show_#{model}/#{b}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{b}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{b}|, (p/:form)[2][:action]
      assert_equal "#{root}/browse_#{model}?page=2", (p/:a)[0][:href]
      assert_equal 'Next Page', (p/:a)[0].inner_html

      # Check second object shows up on second browse page
      p = page(port, (p/:a)[0][:href])
      assert_match %r|#{root}/show_#{model}/#{t}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{t}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{t}|, (p/:form)[2][:action]
      assert_equal "#{root}/browse_#{model}?page=1", (p/:a)[0][:href]
      assert_equal 'Previous Page', (p/:a)[0].inner_html

      # Check link goes back to first browse page
      p = page(port, (p/:a)[0][:href])
      assert_match %r|#{root}/show_#{model}/#{b}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{b}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{b}|, (p/:form)[2][:action]
      assert_equal "#{root}/browse_#{model}?page=2", (p/:a)[0][:href]
      assert_equal 'Next Page', (p/:a)[0].inner_html

      # Get param list suffix
      p = page(port, "#{root}/search_#{model}")
      null = p.at('select#null')[:name]
      notnull = p.at('select#notnull')[:name]

      # Check searching for Best brings up one item
      p = page(port, "#{root}/results_#{model}?#{model}[name]=Best")
      assert_match %r|#{root}/show_#{model}/#{b}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{b}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{b}|, (p/:form)[2][:action]
      assert_equal 3, (p/:form).length

      # Check searching for Test brings up one item
      p = page(port, "#{root}/results_#{model}?#{model}[name]=Test")
      assert_match %r|#{root}/show_#{model}/#{t}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{t}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{t}|, (p/:form)[2][:action]
      assert_equal 3, (p/:form).length

      # Check searching for null name brings up no items
      p = page(port, "#{root}/results_#{model}?#{null}=name")
      assert_equal 0, (p/:form).length

      # Check first object shows up on first search page
      p = page(port, "#{root}/results_#{model}?#{notnull}=name")
      assert_match %r|#{root}/show_#{model}/#{b}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{b}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{b}|, (p/:form)[2][:action]
      assert_equal "#{root}/results_#{model}", (p/:form)[3][:action]
      assert_equal "post", (p/:form)[3][:method]
      assert_equal "page", (p/:input)[3][:name]
      assert_equal "1", (p/:input)[3][:value]
      assert_equal "hidden", (p/:input)[3][:type]
      assert_equal notnull, (p/:input)[4][:name]
      assert_equal "name", (p/:input)[4][:value]
      assert_equal "hidden", (p/:input)[4][:type]
      assert_equal 'page_next', (p/:input)[5][:name]
      assert_equal "Next Page", (p/:input)[5][:value]
      assert_equal "submit", (p/:input)[5][:type]

      # Check second object shows up on second search page
      p = page(port, "#{root}/results_#{model}?#{notnull}=name&page_next=Next+Page&page=1")
      assert_match %r|#{root}/show_#{model}/#{t}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{t}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{t}|, (p/:form)[2][:action]
      assert_equal "#{root}/results_#{model}", (p/:form)[3][:action]
      assert_equal "post", (p/:form)[3][:method]
      assert_equal "page", (p/:input)[3][:name]
      assert_equal "2", (p/:input)[3][:value]
      assert_equal "hidden", (p/:input)[3][:type]
      assert_equal notnull, (p/:input)[4][:name]
      assert_equal "name", (p/:input)[4][:value]
      assert_equal "hidden", (p/:input)[4][:type]
      assert_equal 'page_previous', (p/:input)[5][:name]
      assert_equal "Previous Page", (p/:input)[5][:value]
      assert_equal "submit", (p/:input)[5][:type]

      # Check first object shows up on first search page
      p = page(port, "#{root}/results_#{model}?#{notnull}=name&page_previous=Previous+Page&page=2")
      assert_match %r|#{root}/show_#{model}/#{b}|, (p/:form)[0][:action]
      assert_match %r|#{root}/edit_#{model}/#{b}|, (p/:form)[1][:action]
      assert_match %r|#{root}/destroy_#{model}/#{b}|, (p/:form)[2][:action]
      assert_equal "#{root}/results_#{model}", (p/:form)[3][:action]
      assert_equal "post", (p/:form)[3][:method]
      assert_equal "page", (p/:input)[3][:name]
      assert_equal "1", (p/:input)[3][:value]
      assert_equal "hidden", (p/:input)[3][:type]
      assert_equal notnull, (p/:input)[4][:name]
      assert_equal "name", (p/:input)[4][:value]
      assert_equal "hidden", (p/:input)[4][:type]
      assert_equal 'page_next', (p/:input)[5][:name]
      assert_equal "Next Page", (p/:input)[5][:value]
      assert_equal "submit", (p/:input)[5][:type]
    end
  end

  def test_05_merge(port, root)
    # Merge employees
    p = page(port, "#{root}/merge_employee")
    assert_equal 6, (p/:option).length
    assert_match /\d+/, (p/:option)[1][:value]
    assert_equal "Bestemployee", (p/:option)[1].inner_html
    assert_match /\d+/, (p/:option)[2][:value]
    assert_equal "Testemployee", (p/:option)[2].inner_html
    b = (p/:option)[1][:value]
    t = (p/:option)[2][:value]
    res = post(port, p.at(:form)[:action], (p/:select)[0][:name]=>b, (p/:select)[1][:name]=>t)
    assert_se_path port, root, "/merge_employee", res['Location']

    # Check now only 1 employee exists
    p = page(port, "#{root}/merge_employee")
    assert_equal 4, (p/:option).length
    assert_equal t, (p/:option)[1][:value]
    assert_equal "Testemployee", (p/:option)[1].inner_html
    assert_equal t, (p/:option)[3][:value]
    assert_equal "Testemployee", (p/:option)[3].inner_html

    # Edit employee's groups page
    p = page(port, "#{root}/edit_employee_groups/#{t}")
    assert_equal "Update Testemployee's groups", p.at(:h1).inner_html
    assert_equal "#{root}/update_employee_groups/#{t}", p.at(:form)[:action]
    assert_equal "post", p.at(:form)[:method]
    assert_equal 'Add these groups', p.at(:h4).inner_html
    assert_equal 'add', p.at(:select)[:id]
    assert_equal 'add', p.at(:select)[:name].sub('[]', '')
    assert_equal 'multiple', p.at(:select)[:multiple]
    assert_match /\d+/, (p/:option).first[:value]
    assert_match /\d+/, (p/:option).last[:value]
    assert_equal 'Bestgroup', (p/:option).first.inner_html
    assert_equal 'Testgroup', (p/:option).last.inner_html
    bg = (p/:option).first[:value]
    tg = (p/:option).last[:value]
    assert_equal 2, (p/'select#add option').length
    assert_equal 0, (p/'select#remove option').length

    # Update the groups
    res = post(port, p.at(:form)[:action], p.at(:select)[:name]=>bg)
    assert_se_path port, root, "/edit_employee_groups/#{t}", res['Location']
    p = page(port, "#{root}/edit_employee_groups/#{t}")
    assert_equal 1, (p/'select#add option').length
    assert_equal 1, (p/'select#remove option').length
    assert_equal 'Testgroup', p.at('select#add option').inner_html
    assert_equal 'Bestgroup', p.at('select#remove option').inner_html
    assert_equal tg, p.at('select#add option')[:value]
    assert_equal bg, p.at('select#remove option')[:value]

    # Merge groups
    p = page(port, "#{root}/merge_group")
    assert_equal 6, (p/:option).length
    assert_equal bg, (p/:option)[1][:value]
    assert_equal "Bestgroup", (p/:option)[1].inner_html
    assert_equal tg, (p/:option)[2][:value]
    assert_equal "Testgroup", (p/:option)[2].inner_html
    res = post(port, p.at(:form)[:action], (p/:select)[0][:name]=>bg, (p/:select)[1][:name]=>tg)
    assert_se_path port, root, "/merge_group", res['Location']

    # Check now only 1 group exist
    p = page(port, "#{root}/merge_group")
    assert_equal 4, (p/:option).length
    assert_equal tg, (p/:option)[1][:value]
    assert_equal "Testgroup", (p/:option)[1].inner_html
    assert_equal tg, (p/:option)[3][:value]
    assert_equal "Testgroup", (p/:option)[3].inner_html

    # Check employee now in the Testgroup
    p = page(port, "#{root}/edit_employee_groups/#{t}")
    assert_equal 0, (p/'select#add').length
    assert_equal 1, (p/'select#remove option').length
    assert_equal 'Testgroup', p.at('select#remove option').inner_html
    assert_equal tg, p.at('select#remove option')[:value]
    
    # Remove employee from Testgroup
    res = post(port, p.at(:form)[:action], p.at(:select)[:name]=>tg)
    assert_se_path port, root, "/edit_employee_groups/#{t}", res['Location']

    # Check position of employee
    p = page(port, "#{root}/edit_employee/#{t}")
    assert_equal 3, (p/'select#employee_position_id option').length
    assert_equal 'Bestposition', (p/'select#employee_position_id option')[1].inner_html
    assert_equal 'Testposition', (p/'select#employee_position_id option')[2].inner_html
    assert_match /\d+/, (p/'select#employee_position_id option')[1][:value]
    assert_match /\d+/, (p/'select#employee_position_id option')[2][:value]
    bp = (p/'select#employee_position_id option')[1][:value]
    tp = (p/'select#employee_position_id option')[2][:value]
    assert_equal nil, (p/:option)[1][:selected]
    assert_equal 'selected', (p/:option)[2][:selected]

    # Merge position 
    p = page(port, "#{root}/merge_position")
    assert_equal 6, (p/:option).length
    assert_equal bp, (p/:option)[1][:value]
    assert_equal "Bestposition", (p/:option)[1].inner_html
    assert_equal tp, (p/:option)[2][:value]
    assert_equal "Testposition", (p/:option)[2].inner_html
    res = post(port, p.at(:form)[:action], (p/:select)[0][:name]=>tp, (p/:select)[1][:name]=>bp)
    assert_se_path port, root, "/merge_position", res['Location']

    # Check now only 1 position exist
    p = page(port, "#{root}/merge_position")
    assert_equal 4, (p/:option).length
    assert_equal bp, (p/:option)[1][:value]
    assert_equal "Bestposition", (p/:option)[1].inner_html
    assert_equal bp, (p/:option)[3][:value]
    assert_equal "Bestposition", (p/:option)[3].inner_html

    # Check position of employee now Bestposition
    p = page(port, "#{root}/edit_employee/#{t}")
    assert_equal 2, (p/'select#employee_position_id option').length
    assert_equal 'Bestposition', (p/'select#employee_position_id option')[1].inner_html
    assert_equal bp, (p/'select#employee_position_id option')[1][:value]
    assert_equal 'selected', (p/'select#employee_position_id option')[1][:selected]
  end

  def test_06_update(port, root)
    %w'employee group position'.each do |model|
      # Get id
      p = page(port, "#{root}/edit_#{model}")
      assert_equal 2, (p/:option).length
      assert_match /\d+/, (p/:option)[1][:value]
      i = (p/:option)[1][:value]

      # Check current name
      p = page(port, "#{root}/edit_#{model}/#{i}")
      assert_equal "est#{model}", p.at("input##{model}_name")[:value][1..-1]

      # Update name
      res = post(port, p.at(:form)[:action], "#{model}[name]"=>"Z#{model}")
      assert_se_path port, root, "/edit_#{model}", res['Location']

      # Check updated name
      p = page(port, "#{root}/edit_#{model}/#{i}")
      assert_equal "Z#{model}", p.at("input##{model}_name")[:value]
    end
  end
  
  def test_07_auto_completing(port, root)
    # Ensure only 1 officer exists
    p = page(port, "#{root}/browse_officer")
    (p/:form).each do |form|
      next unless form[:method] == 'post'
      res = post(port, form[:action], {})
      assert_se_path port, root, "/delete_officer", res['Location']
    end
    res = post(port, "#{root}/create_officer", "officer[name]"=>'Zofficer')
    assert_se_path port, root, "/new_officer", res['Location']
    
    # Test regular auto completing
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z")
    assert_equal 1, (p/:ul).length
    assert_equal 1, (p/:li).length
    assert_match /\d+ - Zofficer/, p.at(:li).inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X")
    assert_equal 1, (p/:ul).length
    assert_equal 0, (p/:li).length
    assert_equal '', p.at(:ul).inner_html
    
    # Tset auto completing for belongs to associations
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z&association=position")
    assert_equal 1, (p/:ul).length
    assert_equal 1, (p/:li).length
    assert_match /\d+ - Zposition/, p.at(:li).inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X&association=position")
    assert_equal 1, (p/:ul).length
    assert_equal 0, (p/:li).length
    assert_equal '', p.at(:ul).inner_html
    
    # Test auto completing for habtm associations
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z&association=groups")
    assert_equal 1, (p/:ul).length
    assert_equal 1, (p/:li).length
    assert_match /\d+ - Zgroup/, p.at(:li).inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X&association=groups")
    assert_equal 1, (p/:ul).length
    assert_equal 0, (p/:li).length
    assert_equal '', p.at(:ul).inner_html
    
    # Check to make sure that auto complete fields exist every place they are expected
    
    # Regular auto complete
    %w'delete edit show'.each do |action|
      p = page(port, "#{root}/#{action}_officer")
      assert_equal 1, (p/"input#id").length
      assert_equal 'text', p.at("input#id")[:type]
      assert_equal 1, (p/"div#id_scaffold_auto_complete").length
      assert_equal 'auto_complete', p.at("div#id_scaffold_auto_complete")[:class]
      assert_equal "\n//<![CDATA[\nvar id_auto_completer = new Ajax.Autocompleter('id', 'id_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", p.at(:script).inner_html
    end
    p = page(port, "#{root}/merge_officer")
    assert_equal 1, (p/"input#from").length
    assert_equal 'text', p.at("input#from")[:type]
    assert_equal 1, (p/"div#from_scaffold_auto_complete").length
    assert_equal 'auto_complete', p.at("div#from_scaffold_auto_complete")[:class]
    assert_equal "\n//<![CDATA[\nvar from_auto_completer = new Ajax.Autocompleter('from', 'from_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", (p/:script)[0].inner_html
    assert_equal 1, (p/"input#to").length
    assert_equal 'text', p.at("input#to")[:type]
    assert_equal 1, (p/"div#to_scaffold_auto_complete").length
    assert_equal 'auto_complete', p.at("div#to_scaffold_auto_complete")[:class]
    assert_equal "\n//<![CDATA[\nvar to_auto_completer = new Ajax.Autocompleter('to', 'to_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", (p/:script)[1].inner_html

    
    # belongs to association auto complete
    p = page(port, "#{root}/browse_officer")
    i = (p/:form)[1][:action].split('/')[-1]
    [:new_officer, :search_officer, "edit_officer/#{i}"].each do |action|
      p = page(port, "#{root}/#{action}")
      assert_equal 1, (p/"div#officer_position_id_scaffold_auto_complete").length
      assert_equal 'auto_complete', p.at("div#officer_position_id_scaffold_auto_complete")[:class]
      assert_equal 1, (p/"input#officer_position_id").length
      assert_equal 'text', p.at("input#officer_position_id")[:type]
      assert_equal 'officer[position_id]', p.at("input#officer_position_id")[:name]
      assert_equal "\n//<![CDATA[\nvar officer_position_id_auto_completer = new Ajax.Autocompleter('officer_position_id', 'officer_position_id_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get', parameters:'association=position'})\n//]]>\n", p.at(:script).inner_html
    end
    
    # habtm association auto complete
    p = page(port, "#{root}/edit_officer_groups/#{i}")
    assert_equal 1, (p/"div#add_scaffold_auto_complete").length
    assert_equal 'auto_complete', p.at("div#add_scaffold_auto_complete")[:class]
    assert_equal 1, (p/"input#add").length
    assert_equal 'text', p.at("input#add")[:type]
    assert_equal "\n//<![CDATA[\nvar add_auto_completer = new Ajax.Autocompleter('add', 'add_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get', parameters:'association=groups'})\n//]]>\n", p.at(:script).inner_html
  end

  test_all_frameworks_and_dbs
end
