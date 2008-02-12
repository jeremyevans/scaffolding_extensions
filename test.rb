#!/usr/bin/env ruby
require 'rubygems'
require 'test/unit'
require 'hpricot'
require 'set'
require 'open-uri'
require 'net/http'
class ScaffoldingExtensionsTest < Test::Unit::TestCase
  HOST='localhost'
  PORT=7000
  SE_ROOT='/admin'
  FIELD_NAMES={'employee'=>%w'Active Comment Name Password Position', 'position'=>%w'Name', 'group'=>%w'Name'}
  FIELDS={'employee'=>%w'active comment name password position_id', 'position'=>%w'name', 'group'=>%w'name'}
  ACTION_MAP={'delete'=>'destroy', 'edit'=>'edit', 'show'=>'show'}

  def se_path(path)
    "http://#{HOST}:#{PORT}/admin#{path}"
  end

  def page(path)
    Hpricot(open("http://#{HOST}:#{PORT}#{path}"))
  end
  
  def post(path, params)
    req = Net::HTTP::Post.new(path)
    req.set_form_data(params)
    Net::HTTP.new(HOST, PORT).start {|http| http.request(req) }
  end

  def test_00_clear_db
    %w'employee position group'.each do |model|
      p = page("#{SE_ROOT}/show_#{model}")
      opts = p/:option
      opts.shift
      opts.each do |opt| 
        res = post("#{SE_ROOT}/destroy_#{model}", :id=>opt[:value])
        assert_equal se_path("/delete_#{model}"), res['Location']
      end
    end
  end

  def test_01_blank
     href = SE_ROOT
     p = page(href)    
     assert_equal 'Scaffolding Extensions - Manage Models', p.at(:title).inner_html
     assert_equal 'Manage Models', p.at(:h1).inner_html
     assert_equal 1, (p/:ul).length
     assert_equal 3, (p/:ul/:li).length
     assert_equal %w'Employee Position Group', (p/:a).collect{|x| x.inner_html}
     (p/:a).each do |el|
       href1 = el[:href]
       p1 = page(href1)
       sn = el.inner_html.downcase
       assert_equal "Scaffolding Extensions - Manage #{sn}s", p1.at(:title).inner_html
       assert_equal "Manage #{sn}s", p1.at(:h1).inner_html
       assert_equal 1, (p1/:ul).length
       assert_equal 7, (p1/:ul/:li).length
       assert_equal 8, (p1/:a).length
       assert_equal 7, (p1/:ul/:a).length
       assert_equal 'Manage Models', (p1/:a).last.inner_html
       assert_match %r{\A#{href}(/index)?\z}, (p1/:a).last[:href]
       (p1/:ul/:a).each do |el1|
         manage_re = %r{\A(Browse|Create|Delete|Edit|Merge|Search|Show) #{sn}s?\z}
         assert_match manage_re, el1.inner_html
         manage_re = %r{\A/admin/(browse|new|delete|edit|merge|search|show)_#{sn}\z}
         assert_match manage_re, el1[:href]
         page_type = manage_re.match(el1[:href])[1]
         p2 = page(el1[:href])
         case page_type
           when 'browse'
             assert_equal "Scaffolding Extensions - Listing #{sn}s", p2.at(:title).inner_html
             assert_equal "Listing #{sn}s", p2.at(:h1).inner_html
             assert_equal FIELD_NAMES[sn]+%w'Show Edit Delete', (p2/:th).collect{|x| x.inner_html}
             assert_equal 0, (p2/:td).length
             assert_equal 1, (p2/:a).length
             assert_equal href1, p2.at(:a)[:href]
           when 'new'
             assert_equal "Scaffolding Extensions - Create new #{sn}", p2.at(:title).inner_html
             assert_equal "Create new #{sn}", p2.at(:h1).inner_html
             assert_equal "#{href}/create_#{sn}", p2.at(:form)[:action]
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
             assert_equal "#{href}/#{ACTION_MAP[page_type]}_#{sn}", p2.at(:form)[:action]
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
             assert_equal "#{href}/merge_update_#{sn}", p2.at(:form)[:action]
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
             assert_equal "#{href}/results_#{sn}", p2.at(:form)[:action]
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

  def test_02_create_position_and_group
    %w'position group'.each do |model|
      res = post("#{SE_ROOT}/create_#{model}", "#{model}[name]"=>"Test#{model}")
      assert_equal se_path("/new_#{model}"), res['Location']
    end
  end
  
  def test_03_1_position_and_group
    %w'position group'.each do |model|
      name = "Test#{model}"
      %w'browse results'.each do |action|
        p = page("#{SE_ROOT}/#{action}_#{model}")
        assert_equal 4, (p/:td).length
        assert_equal 3, (p/:form).length
        assert_equal name, (p/:td).first.inner_html
        assert_match %r|#{SE_ROOT}/show_#{model}/\d+|, (p/:form)[0][:action]
        assert_match %r|#{SE_ROOT}/edit_#{model}/\d+|, (p/:form)[1][:action]
        assert_match %r|#{SE_ROOT}/destroy_#{model}/\d+|, (p/:form)[2][:action]
        assert_equal 'get', (p/:form)[0][:method]
        assert_equal 'get', (p/:form)[1][:method]
        assert_equal 'post', (p/:form)[2][:method]
        assert_equal 'Show', (p/:input)[0][:value]
        assert_equal 'Edit', (p/:input)[1][:value]
        assert_equal 'Delete', (p/:input)[2][:value]
      end
  
      %w'show edit delete'.each do |action|
        p = page("#{SE_ROOT}/#{action}_#{model}")
        assert_equal 2, (p/:option).length
        assert_match /\d+/, (p/:option).last[:value]
        assert_equal name, (p/:option).last.inner_html
      end
  
      p = page("#{SE_ROOT}/merge_#{model}")
      assert_equal 4, (p/:option).length
      assert_match /\d+/, (p/:option)[1][:value]
      i = (p/:option)[1][:value]
      assert_equal i, (p/:option)[3][:value]
      assert_equal name, (p/:option)[1].inner_html
      assert_equal name, (p/:option)[3].inner_html
  
      p = page("#{SE_ROOT}/show_#{model}/#{i}")
      assert_equal "#{SE_ROOT}/edit_#{model}/#{i}", (p/:a)[0][:href]
      assert_equal 'Edit', (p/:a)[0].inner_html
      assert_equal 'Attribute', (p/:th)[0].inner_html
      assert_equal 'Value', (p/:th)[1].inner_html
      assert_equal 'Name', (p/:td)[0].inner_html
      assert_equal name, (p/:td)[1].inner_html
      assert_equal 'Associated Records', p.at(:h3).inner_html
      assert_equal 'scaffold_associated_records_header', p.at(:h3)[:class]
      assert_equal "scaffolded_associations_#{model}_#{i}", p.at(:ul)[:id]
      assert_equal 1, (p/:li).length
      assert_equal "#{SE_ROOT}/manage_employee", (p/:a)[1][:href]
      assert_equal "Employees", (p/:a)[1].inner_html
  
      p = page("#{SE_ROOT}/edit_#{model}/#{i}")
      assert_equal "#{SE_ROOT}/update_#{model}/#{i}", p.at(:form)[:action]
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
      assert_equal "#{SE_ROOT}/manage_employee", (p/:a)[0][:href]
      assert_equal "Employees", (p/:a)[0].inner_html
      if model == 'position' 
        assert_equal "#{SE_ROOT}/new_employee?employee%5Bposition_id%5D=#{i}", (p/:a)[1][:href]
        assert_equal '(create)', (p/:a)[1].inner_html
      else
        assert_equal "#{SE_ROOT}/edit_#{model}_employees/#{i}", (p/:a)[1][:href]
        assert_equal '(associate)', (p/:a)[1].inner_html
      end
    end
    
    p = page("#{SE_ROOT}/show_position")
    i = (p/:option).last[:value]
    p = page("#{SE_ROOT}/show_position/#{i}")
    # Check edit link from show page works
    p = page((p/:a).first[:href])
    # Check create employee link on edit position page sets position for employee
    p = page((p/:a)[1][:href])
    assert_equal 3, (p/'select#employee_active option').length
    assert_equal [nil, 'f', 't'], (p/'select#employee_active option').collect{|x| x[:value]}
    assert_equal 'employee_comment', p.at(:textarea)[:id]
    assert_equal 'text', p.at('input#employee_name')[:type]
    assert_equal 'text', p.at('input#employee_password')[:type]
    assert_equal i, (p/'select#employee_position_id option').last[:value]
    assert_equal 'selected', (p/'select#employee_position_id option').last[:selected]
  end

  def test_04_create_employee
    p = page("#{SE_ROOT}/show_position")
    position_id = (p/:option).last[:value]
    res = post("#{SE_ROOT}/create_employee", "employee[name]"=>"Testemployee", 'employee[active]'=>'t', 'employee[comment]'=>'Comment', 'employee[password]'=>'password', 'employee[position_id]'=>position_id)
    assert_equal se_path("/new_employee"), res['Location']
  end

  def test_05_check_associations
    p = page("#{SE_ROOT}/show_position")
    position_id = (p/:option).last[:value]
    p = page("#{SE_ROOT}/show_group")
    group_id = (p/:option).last[:value]
    p = page("#{SE_ROOT}/show_employee")
    i = (p/:option).last[:value]
    p = page("#{SE_ROOT}/show_employee/#{i}")
    assert_equal %w'Active true Comment Comment Name Testemployee Password password Position Testposition', (p/:td).collect{|x| x.inner_html}
    assert_equal 2, (p/:li).length
    assert_equal 5, (p/:a).length
    assert_equal 'Groups', (p/:a)[1].inner_html
    assert_equal 'Position', (p/:a)[2].inner_html
    assert_equal 'Testposition', (p/:a)[3].inner_html
    assert_equal "#{SE_ROOT}/manage_group", (p/:a)[1][:href]
    assert_equal "#{SE_ROOT}/manage_position", (p/:a)[2][:href]
    assert_equal "#{SE_ROOT}/show_position/#{position_id}", (p/:a)[3][:href]

    # Edit page
    p1 = p = page((p/:a)[0][:href])
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
    assert_equal "#{SE_ROOT}/manage_group", (p/:a)[0][:href]
    assert_equal "#{SE_ROOT}/edit_employee_groups/#{i}", (p/:a)[1][:href]
    assert_equal "#{SE_ROOT}/manage_position", (p/:a)[2][:href]
    assert_equal "#{SE_ROOT}/edit_position/#{position_id}", (p/:a)[3][:href]

    # Edit employee's groups page
    p = page((p/:a)[1][:href])
    assert_equal "Update Testemployee's groups", p.at(:h1).inner_html
    assert_equal "#{SE_ROOT}/update_employee_groups/#{i}", p.at(:form)[:action]
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
    assert_equal "#{SE_ROOT}/edit_employee/#{i}", p.at(:a)[:href]

    # Update the groups
    res = post(p.at(:form)[:action], p.at(:select)[:name]=>p.at(:option)[:value])
    assert_equal se_path("/edit_employee_groups/#{i}"), res['Location']

    # Recheck the habtm page
    p = page((p1/:a)[1][:href])
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
    p = page(p.at(:a)[:href])
    assert_equal 'Groups', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Testgroup', (p/:a)[2].inner_html
    assert_equal 'Position', (p/:a)[3].inner_html
    assert_equal 'Testposition', (p/:a)[4].inner_html
    assert_equal "#{SE_ROOT}/manage_group", (p/:a)[0][:href]
    assert_equal "#{SE_ROOT}/edit_employee_groups/#{i}", (p/:a)[1][:href]
    assert_equal "#{SE_ROOT}/edit_group/#{group_id}", (p/:a)[2][:href]
    assert_equal "#{SE_ROOT}/manage_position", (p/:a)[3][:href]
    assert_equal "#{SE_ROOT}/edit_position/#{position_id}", (p/:a)[4][:href]

    # Check working link to group page
    p = page((p/:a)[2][:href])
    assert_equal 'Employees', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Testemployee', (p/:a)[2].inner_html
    assert_equal "#{SE_ROOT}/manage_employee", (p/:a)[0][:href]
    assert_equal "#{SE_ROOT}/edit_group_employees/#{group_id}", (p/:a)[1][:href]
    assert_equal "#{SE_ROOT}/edit_employee/#{i}", (p/:a)[2][:href]

    # Edit group's employees page
    p = page((p/:a)[1][:href])
    assert_equal "Update Testgroup's employees", p.at(:h1).inner_html
    assert_equal "#{SE_ROOT}/update_group_employees/#{group_id}", p.at(:form)[:action]
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
    res = post(p.at(:form)[:action], p.at(:select)[:name]=>p.at(:option)[:value])
    assert_equal se_path("/edit_group_employees/#{group_id}"), res['Location']

    # Recheck the edit group page
    p = page(p.at(:a)[:href])
    assert_equal 'Employees', (p/:a)[0].inner_html
    assert_equal '(associate)', (p/:a)[1].inner_html
    assert_equal 'Manage groups', (p/:a)[2].inner_html
    assert_equal "#{SE_ROOT}/manage_employee", (p/:a)[0][:href]
    assert_equal "#{SE_ROOT}/edit_group_employees/#{group_id}", (p/:a)[1][:href]
  end

  alias test_98_clear_db test_00_clear_db
  alias test_99_blank test_01_blank
end
