#!/usr/bin/env ruby
require 'rubygems'
require 'test/unit'
require 'hpricot'
require 'set'
require 'open-uri'
require 'net/http'

ORMS = {}
POSSIBLE_ORMS = %w'active_record sequel'
ORM_MAP = {'active_record'=>'ar', 'sequel'=>'asq'}
FRAMEWORKS = {'rails'=>7979, 'ramaze'=>7978, 'camping'=>7977, 'sinatra'=>7976, 'merb'=>7975}
PORTS = FRAMEWORKS.invert

ARGV.each do |arg|
  raise ArgumentError, 'Not a valid ORM or framework' unless POSSIBLE_ORMS.include?(arg) || FRAMEWORKS.include?(arg)
  POSSIBLE_ORMS.replace([arg]) if POSSIBLE_ORMS.include?(arg)
  FRAMEWORKS.replace({arg=>FRAMEWORKS[arg]}) if FRAMEWORKS.include?(arg)
end
FRAMEWORKS.each{|k,v| ORMS[v] = POSSIBLE_ORMS}
ORMS[FRAMEWORKS['merb']] = POSSIBLE_ORMS.map{|v| ORM_MAP[v]}

class ScaffoldingExtensionsTest < Test::Unit::TestCase
  HOST='localhost'
  FIELD_NAMES={'employee'=>%w'Active Comment Name Password Position', 'position'=>%w'Name', 'group'=>%w'Name'}
  FIELDS={'employee'=>%w'active comment name password position_id', 'position'=>%w'name', 'group'=>%w'name'}
  ACTION_MAP={'delete'=>'destroy', 'edit'=>'edit', 'show'=>'show'}

  def test_all_frameworks_and_dbs
    meths = methods.sort.grep(/\A_test_\d\d/)
    FRAMEWORKS.values.sort.reverse.each do |port|
      t0 = Time.now
      ORMS[port].each do |root|
        t1 = Time.now
        meths.each do |meth|
          print "#{PORTS[port]} #{root} #{meth} "
          t2 = Time.now
          send(meth, port, "/#{root}") rescue (puts "Error! framework:#{PORTS[port]} orm:#{root} meth:#{meth}"; raise)
          puts "%.3f" % (Time.now - t2)
        end
        puts "#{PORTS[port]} #{root} %.3f" % (Time.now - t1)
      end
      puts "#{PORTS[port]} %.3f" % (Time.now - t0)
    end
  end

  def assert_se_path(port, root, path, location)
    assert_equal "#{root}#{path}", location.sub(%r{^(http:)?//#{HOST}:#{port}}, '')
  end
  
  def prototype?
    @js_lib == :prototype
  end

  def page(port, path)
    f = open("http://#{HOST}:#{port}#{path}")
    h = Hpricot(f)
    f.close
    h
  end
  
  def post(port, path, params)
    req = Net::HTTP::Post.new(path)
    req.set_form_data(params)
    Net::HTTP.new(HOST, port).start{|http| http.request(req)}
  end
  
  def post_xhr(port, path, params)
    req = Net::HTTP::Post.new(path)
    req.set_form_data(params)
    req['X-Requested-With'] = 'XMLHttpRequest'
    res = Net::HTTP.new(HOST, port).start{|http| http.request(req)}
    assert_match %r{\Atext/javascript},  res['Content-Type']
    res
  end

  def post_multiple(port, path, param, values)
    req = Net::HTTP::Post.new(path)
    req.body = values.collect{|v| "#{param}=#{v}"}.join('&')
    req.content_type = 'application/x-www-form-urlencoded'
    Net::HTTP.new(HOST, port).start{|http| http.request(req)}
  end

  def _test_00_clear_db(port, root)
    %w'employee position group meeting'.each do |model|
      p = page(port, "#{root}/show_#{model}")
      opts = p/:option
      opts.shift
      opts.each do |opt| 
        res = post(port, "#{root}/destroy_#{model}", 'id'=>opt[:value])
        assert_se_path port, root, "/delete_#{model}", res['Location']
      end
    end
  end

  def _test_01_no_objects(port, root)
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
  
  def _test_02_simple_object(port, root)
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

  def _test_03_complex_object_and_relationships(port, root)
    p = page(port, "#{root}/show_position")
    position_id = (p/:option).last[:value]
    p = page(port, "#{root}/show_group")
    group_id = (p/:option).last[:value]
    
    res = post(port, "#{root}/create_employee", "employee[name]"=>"Testemployee", 'employee[active]'=>'f', 'employee[comment]'=>'Comment', 'employee[password]'=>'password', 'employee[position_id]'=>position_id)
    assert_se_path port, root, "/new_employee", res['Location']
    
    p = page(port, "#{root}/show_employee")
    i = (p/:option).last[:value]

    # Show page
    p = page(port, "#{root}/show_employee/#{i}")
    assert_equal %w'Active false Comment Comment Name Testemployee Password password Position Testposition', (p/:td).collect{|x| x.inner_html}
    assert_equal 2, (p/:li).length
    assert_equal 5, (p/:a).length
    assert_equal 'Groups', (p/:a)[1].inner_html
    assert_equal 'Position', (p/:a)[2].inner_html
    assert_equal 'Testposition', (p/:a)[3].inner_html
    assert_equal "#{root}/manage_group", (p/:a)[1][:href]
    assert_equal "#{root}/manage_position", (p/:a)[2][:href]
    assert_equal "#{root}/show_position/#{position_id}", (p/:a)[3][:href]

    # Make sure all boolean values work
    res = post(port, "#{root}/update_employee/#{i}", 'employee[active]'=>'')
    assert_se_path port, root, "/edit_employee", res['Location']
    p = page(port, "#{root}/show_employee/#{i}")
    assert_equal 'Active//Comment/Comment/Name/Testemployee/Password/password/Position/Testposition'.split('/'), (p/:td).collect{|x| x.inner_html}
    res = post(port, "#{root}/update_employee/#{i}", 'employee[active]'=>'t')
    assert_se_path port, root, "/edit_employee", res['Location']
    p = page(port, "#{root}/show_employee/#{i}")
    assert_equal %w'Active true Comment Comment Name Testemployee Password password Position Testposition', (p/:td).collect{|x| x.inner_html}

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

  def _test_04_browse_search(port, root)
    position_id = nil
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

      if model == 'position'
        position_id = t
      elsif model == 'employee'
        # Check searching for employee by position id
        p = page(port, "#{root}/results_#{model}?#{model}[position_id]=#{position_id}")
        assert_match %r|#{root}/show_#{model}/#{t}|, (p/:form)[0][:action]
        assert_match %r|#{root}/edit_#{model}/#{t}|, (p/:form)[1][:action]
        assert_match %r|#{root}/destroy_#{model}/#{t}|, (p/:form)[2][:action]
        assert_equal 3, (p/:form).length
        # Check searching for employee by boolean field
        p = page(port, "#{root}/results_#{model}?#{model}[active]=t")
        assert_match %r|#{root}/show_#{model}/#{t}|, (p/:form)[0][:action]
        assert_match %r|#{root}/edit_#{model}/#{t}|, (p/:form)[1][:action]
        assert_match %r|#{root}/destroy_#{model}/#{t}|, (p/:form)[2][:action]
        assert_equal 3, (p/:form).length
        p = page(port, "#{root}/results_#{model}?#{model}[active]=f")
        assert_equal 0, (p/:form).length
      end

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

  def _test_05_merge(port, root)
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

    # Update both groups at once
    res = post_multiple(port, p.at(:form)[:action], p.at('select#add')[:name], [tg, bg])
    assert_se_path port, root, "/edit_employee_groups/#{t}", res['Location']
    p = page(port, "#{root}/edit_employee_groups/#{t}")
    assert_equal 'Remove these groups', p.at(:h4).inner_html
    assert_equal 'remove', p.at(:select)[:id]
    assert_equal 'remove', p.at(:select)[:name].sub('[]', '')
    assert_equal 'multiple', p.at(:select)[:multiple]
    assert_equal 0, (p/'select#add option').length
    assert_equal 2, (p/'select#remove option').length

    assert_equal 'Bestgroup', (p/:option).first.inner_html
    assert_equal 'Testgroup', (p/:option).last.inner_html
    assert_equal bg, (p/:option).first[:value]
    assert_equal tg, (p/:option).last[:value]

    # Update the groups
    res = post(port, p.at(:form)[:action], p.at('select#remove')[:name]=>tg)
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

  def _test_06_update(port, root)
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
  
  def _test_07_auto_completing(port, root)
    # Ensure only 1 officer exists
    p = page(port, "#{root}/browse_officer")
    (p/:form).each do |form|
      next unless form[:method] == 'post'
      res = post(port, form[:action], {})
      assert_se_path port, root, "/delete_officer", res['Location']
    end
    res = post(port, "#{root}/create_officer", "officer[name]"=>'Zofficer')
    assert_se_path port, root, "/new_officer", res['Location']
    p = page(port, "#{root}/browse_officer")
    i = (p/:form)[1][:action].split('/')[-1]
    
    # Check to make sure that auto complete fields exist every place they are expected
    
    # Regular auto complete
    p = page(port, "#{root}/merge_officer")
    assert_equal 1, (p/"input#from").length
    assert_equal 'text', p.at("input#from")[:type]
    if 1 == (p/"div#from_scaffold_auto_complete").length
      @js_lib = :prototype
      assert_equal 'auto_complete', p.at("div#from_scaffold_auto_complete")[:class]
      assert_equal "\n//<![CDATA[\nvar from_auto_completer = new Ajax.Autocompleter('from', 'from_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", (p/:script)[0].inner_html
    else
      @js_lib = :jquery
      assert_equal 'autocomplete', p.at("input#from")[:class]
      assert_equal "\n//<![CDATA[\n$('#from').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_officer'});\n//]]>\n", (p/:script)[0].inner_html
    end
    assert_equal 1, (p/"input#to").length
    assert_equal 'text', p.at("input#to")[:type]
    if prototype?
      assert_equal 'auto_complete', p.at("div#to_scaffold_auto_complete")[:class]
      assert_equal "\n//<![CDATA[\nvar to_auto_completer = new Ajax.Autocompleter('to', 'to_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", (p/:script)[1].inner_html
    else
      assert_equal 'autocomplete', p.at("input#to")[:class]
      assert_equal "\n//<![CDATA[\n$('#to').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_officer'});\n//]]>\n", (p/:script)[1].inner_html
    end
    
    %w'delete edit show'.each do |action|
      p = page(port, "#{root}/#{action}_officer")
      assert_equal 1, (p/"input#id").length
      assert_equal 'text', p.at("input#id")[:type]
      if prototype?
        assert_equal 'auto_complete', p.at("div#id_scaffold_auto_complete")[:class]
        assert_equal "\n//<![CDATA[\nvar id_auto_completer = new Ajax.Autocompleter('id', 'id_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get'})\n//]]>\n", p.at(:script).inner_html
      else
        assert_equal 'autocomplete', p.at("input#id")[:class]
        assert_equal "\n//<![CDATA[\n$('#id').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_officer'});\n//]]>\n", p.at(:script).inner_html
      end
    end
    
    # belongs to association auto complete
    [:new_officer, :search_officer, "edit_officer/#{i}"].each do |action|
      p = page(port, "#{root}/#{action}")
      assert_equal 1, (p/"input#officer_position_id").length
      assert_equal 'text', p.at("input#officer_position_id")[:type]
      assert_equal 'officer[position_id]', p.at("input#officer_position_id")[:name]
      if prototype?
        assert_equal 'auto_complete', p.at("div#officer_position_id_scaffold_auto_complete")[:class]
        assert_equal "\n//<![CDATA[\nvar officer_position_id_auto_completer = new Ajax.Autocompleter('officer_position_id', 'officer_position_id_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get', parameters:'association=position'})\n//]]>\n", p.at(:script).inner_html
      else
        assert_equal 'autocomplete', p.at("input#officer_position_id")[:class]
        assert_equal "\n//<![CDATA[\n$('#officer_position_id').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_officer', association:'position'});\n//]]>\n", p.at(:script).inner_html
      end
    end
    
    # habtm association auto complete
    p = page(port, "#{root}/edit_officer_groups/#{i}")
    assert_equal 1, (p/"input#add").length
    assert_equal 'text', p.at("input#add")[:type]
    if prototype?
      assert_equal 'auto_complete', p.at("div#add_scaffold_auto_complete")[:class]
      assert_equal "\n//<![CDATA[\nvar add_auto_completer = new Ajax.Autocompleter('add', 'add_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_officer', {paramName:'id', method:'get', parameters:'association=groups'})\n//]]>\n", p.at(:script).inner_html
    else
      assert_equal 'autocomplete', p.at("input#add")[:class]
      assert_equal "\n//<![CDATA[\n$('#add').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_officer', association:'groups'});\n//]]>\n", p.at(:script).inner_html
    end
  
    # Test regular auto completing
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z")
    assert_equal "<ul><li>#{i} - Zofficer</li></ul>", p.inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X")
    assert_equal '<ul></ul>', p.inner_html
    
    # Tset auto completing for belongs to associations
    p = page(port, "#{root}/browse_position")
    ip = (p/:form)[1][:action].split('/')[-1]
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z&association=position")
    assert_equal "<ul><li>#{ip} - Zposition</li></ul>", p.inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X&association=position")
    assert_equal '<ul></ul>', p.inner_html
    
    # Test auto completing for habtm associations
    p = page(port, "#{root}/browse_group")
    ig = (p/:form)[1][:action].split('/')[-1]
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=Z&association=groups")
    assert_equal "<ul><li>#{ig} - Zgroup</li></ul>", p.inner_html
    p = page(port, "#{root}/scaffold_auto_complete_for_officer?id=X&association=groups")
    assert_equal '<ul></ul>', p.inner_html
  end
  
  def _test_08_ajax(port, root)
    res = post(port, "#{root}/create_meeting", "meeting[name]"=>'Zmeeting')
    assert_se_path port, root, "/new_meeting", res['Location']
    p = page(port, "#{root}/edit_meeting")
    i = (p/:option).last[:value]
    p = page(port, "#{root}/browse_position")
    pi = (p/:form)[1][:action].split('/')[-1]
    
    # Check for load associations link
    p = page(port, "#{root}/edit_meeting/#{i}")
    assert_equal "scaffold_ajax_content_#{i}", p.at("div#scaffold_ajax_content_#{i}")[:id]
    assert_equal 'Modify Associations', p.at(:a).inner_html
    assert_equal "#{root}/edit_meeting/#{i}?associations=show", p.at(:a)[:href]
    if "$('#scaffold_ajax_content_#{i}').load('#{root}/associations_meeting/#{i}'); return false;" == p.at(:a)[:onclick]
      @js_lib = :jquery
      assert_equal "$('#scaffold_ajax_content_#{i}').load('#{root}/associations_meeting/#{i}'); return false;", p.at(:a)[:onclick]
    else
      @js_lib = :prototype
      assert_equal "new Ajax.Updater('scaffold_ajax_content_#{i}', '#{root}/associations_meeting/#{i}', {method:'get', asynchronous:true, evalScripts:true}); return false;", p.at(:a)[:onclick]
    end
    
    # Check that edit page with associations parameter has associations
    p = page(port, "#{root}/edit_meeting/#{i}?associations=show")
    assert_equal 1, (p/"div#meeting_habtm_ajax_remove_associations ul").length
    
    # Check that associations link brings up the appropriate form widgets
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 'habtm_ajax_add_associations', (p/:div).first[:class]
    assert_equal 'meeting_habtm_ajax_add_associations', (p/:div).first[:id]
    assert_equal 'habtm_ajax_remove_associations', (p/:div).last[:class]
    assert_equal 'meeting_habtm_ajax_remove_associations', (p/:div).last[:id]
    assert_equal 2, (p/:ul).length
    assert_equal 1, (p/"div#meeting_habtm_ajax_remove_associations ul").length
    assert_equal 'meeting_associated_records_list', p.at("div#meeting_habtm_ajax_remove_associations ul")[:id]
    assert_equal '', p.at("div#meeting_habtm_ajax_remove_associations ul").inner_html.strip
    assert_equal 1, (p/"ul#scaffolded_associations_meeting_#{i}").length
    assert_equal '', p.at("ul#scaffolded_associations_meeting_#{i}").inner_html.strip
    assert_equal 0, (p/:li).length
    assert_equal 2, (p/:form).length
    assert_equal 2, (p/"div#meeting_habtm_ajax_add_associations form").length
    assert_equal 'post', (p/:form).first[:method]
    assert_equal 'post', (p/:form).last[:method]
    assert_equal "#{root}/add_groups_to_meeting/#{i}", (p/:form).first[:action]
    assert_equal "#{root}/add_positions_to_meeting/#{i}", (p/:form).last[:action]
    if prototype?
      assert_equal 3, (p/:div).length
      assert_equal "new Ajax.Request('#{root}/add_groups_to_meeting/#{i}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;", (p/:form).first[:onsubmit]
      assert_equal "new Ajax.Request('#{root}/add_positions_to_meeting/#{i}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;", (p/:form).last[:onsubmit]
    else
      assert_equal 2, (p/:div).length
      assert_equal "$.post('#{root}/add_groups_to_meeting/#{i}', $(this).serialize(), function(data, textStatus){eval(data);}); return false;", (p/:form).first[:onsubmit]
      assert_equal "$.post('#{root}/add_positions_to_meeting/#{i}', $(this).serialize(), function(data, textStatus){eval(data);}); return false;", (p/:form).last[:onsubmit]
    end
    assert_equal 1, (p/"select#meeting_groups_id").length
    assert_equal 2, (p/:option).length
    assert_equal 2, (p/"select#meeting_groups_id option").length
    gi = (p/:option).last[:value]
    assert_equal nil, (p/:option).first[:value]
    assert_equal '', (p/:option).first.inner_html
    assert_equal "meeting_groups_id_#{gi}", (p/:option).last[:id]
    assert_equal 'Zgroup', (p/:option).last.inner_html
    assert_equal 1, (p/"input#meeting_positions_id").length
    assert_equal 'meeting_positions_id', p.at("input#meeting_positions_id")[:name]
    assert_equal 'autocomplete', p.at("input#meeting_positions_id")[:class]
    assert_equal '', p.at("input#meeting_positions_id")[:value]
    assert_equal 'text', p.at("input#meeting_positions_id")[:type]
    if prototype?
      assert_equal 'auto_complete', p.at("div#meeting_positions_id_scaffold_auto_complete")[:class]
      assert_equal "\n//<![CDATA[\nvar meeting_positions_id_auto_completer = new Ajax.Autocompleter('meeting_positions_id', 'meeting_positions_id_scaffold_auto_complete', '#{root}/scaffold_auto_complete_for_meeting', {paramName:'id', method:'get', parameters:'association=positions'})\n//]]>\n", p.at(:script).inner_html
    else
      assert_equal 'autocomplete', p.at("input#meeting_positions_id")[:class]
      assert_equal "\n//<![CDATA[\n$('#meeting_positions_id').autocomplete({ajax:'#{root}/scaffold_auto_complete_for_meeting', association:'positions'});\n//]]>\n", p.at(:script).inner_html
    end
    assert_equal 3, (p/:input).length
    assert_equal 'Add Group', (p/:input)[0][:value]
    assert_equal 'commit', (p/:input)[0][:name]
    assert_equal 'submit', (p/:input)[0][:type]
    assert_equal '', (p/:input)[1][:value]
    assert_equal 'meeting_positions_id', (p/:input)[1][:name]
    assert_equal 'text', (p/:input)[1][:type]
    assert_equal 'Add Position', (p/:input)[2][:value]
    assert_equal 'commit', (p/:input)[2][:name]
    assert_equal 'submit', (p/:input)[2][:type]
    
    # Add Group and see if it appears in the association page
    res = post(port, "#{root}/add_groups_to_meeting/#{i}", 'meeting_groups_id'=>gi)
    assert_se_path port, root, "/edit_meeting/#{i}", res['Location']
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 1, (p/:option).length
    assert_equal nil, (p/:option).first[:value]
    assert_equal '', (p/:option).first.inner_html
    assert_equal 1, (p/:li).length
    assert_equal "meeting_#{i}_groups_#{gi}", p.at(:li)[:id]
    assert_equal 2, (p/"li a").length
    assert_equal 'Groups', (p/"li a").first.inner_html
    assert_equal 'Zgroup', (p/"li a").last.inner_html
    assert_equal "#{root}/manage_group", (p/"li a").first[:href]
    assert_equal "#{root}/edit_group/#{gi}", (p/"li a").last[:href]
    assert_equal 1, (p/"li form").length
    assert_equal "post", p.at("li form")[:method]
    assert_equal "#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}", p.at("li form")[:action]
    if prototype?
      assert_equal "new Ajax.Request('#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;", p.at("li form")[:onsubmit]
    else
      assert_equal "$.post('#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}', $(this).serialize(), function(data, textStatus){eval(data);}); return false;", p.at("li form")[:onsubmit]
    end
    assert_equal 1, (p/"li form input").length
    assert_equal "Remove", p.at("li form input")[:value]
    assert_equal "submit", p.at("li form input")[:type]
    
    # Remove Group and see if it disappears
    res = post(port, "#{root}/remove_groups_from_meeting/#{i}", 'meeting_groups_id'=>gi)
    assert_se_path port, root, "/edit_meeting/#{i}", res['Location']
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 0, (p/:li).length
    
    # Less Extensive Tests for positions association
    res = post(port, "#{root}/add_positions_to_meeting/#{i}", 'meeting_positions_id'=>pi)
    assert_se_path port, root, "/edit_meeting/#{i}", res['Location']
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 1, (p/:li).length
    assert_equal 'Positions', (p/"li a").first.inner_html
    assert_equal 'Zposition', (p/"li a").last.inner_html
    res = post(port, "#{root}/remove_positions_from_meeting/#{i}", 'meeting_positions_id'=>pi)
    assert_se_path port, root, "/edit_meeting/#{i}", res['Location']
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 0, (p/:li).length
    
    # Test Ajax form submission via xhr yields correct javascript and performs action
    res = post_xhr(port, "#{root}/add_groups_to_meeting/#{i}", 'meeting_groups_id'=>gi)
    if prototype?
      assert_equal "new Insertion.Top('meeting_associated_records_list', \"\\u003Cli id='meeting_#{i}_groups_#{gi}'\\u003E\\n\\u003Ca href='#{root}/manage_group'\\u003EGroups\\u003C/a\\u003E - \\n\\u003Ca href='#{root}/edit_group/#{gi}'\\u003EZgroup\\u003C/a\\u003E\\n\\u003Cform method='post' action='#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}' onsubmit=\\\"new Ajax.Request('#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\\\"\\u003E\\n\\n\\n\\u003Cinput type='submit' value=Remove /\\u003E\\n\\u003C/form\\u003E\\n\\u003C/li\\u003E\\n\");\nElement.remove('meeting_groups_id_#{gi}');\n$('meeting_groups_id').selectedIndex = 0;\n", res.body
    else
      assert_equal "$('#meeting_associated_records_list').prepend(\"\\u003Cli id='meeting_#{i}_groups_#{gi}'\\u003E\\n\\u003Ca href='#{root}/manage_group'\\u003EGroups\\u003C/a\\u003E - \\n\\u003Ca href='#{root}/edit_group/#{gi}'\\u003EZgroup\\u003C/a\\u003E\\n\\u003Cform method='post' action='#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}' onsubmit=\\\"$.post('#{root}/remove_groups_from_meeting/#{i}?meeting_groups_id=#{gi}', $(this).serialize(), function(data, textStatus){eval(data);}); return false;\\\"\\u003E\\n\\n\\n\\u003Cinput type='submit' value=Remove /\\u003E\\n\\u003C/form\\u003E\\n\\u003C/li\\u003E\\n\");\n$('#meeting_groups_id_#{gi}').remove();\n$('#meeting_groups_id').selectedIndex = 0;\n", res.body
    end
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 1, (p/:li).length
    assert_equal 'Groups', (p/"li a").first.inner_html
    assert_equal 'Zgroup', (p/"li a").last.inner_html
    
    res = post_xhr(port, "#{root}/remove_groups_from_meeting/#{i}", 'meeting_groups_id'=>gi)
    if prototype?
      assert_equal "Element.remove('meeting_#{i}_groups_#{gi}');\nnew Insertion.Bottom('meeting_groups_id', \"\\u003Coption value='#{gi}' id='meeting_groups_id_#{gi}'\\u003EZgroup\\u003C/option\\u003E\");\n", res.body
    else
      assert_equal "$('#meeting_#{i}_groups_#{gi}').remove();\n$('#meeting_groups_id').append(\"\\u003Coption value='#{gi}' id='meeting_groups_id_#{gi}'\\u003EZgroup\\u003C/option\\u003E\");\n", res.body
    end
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 0, (p/:li).length
    
    res = post_xhr(port, "#{root}/add_positions_to_meeting/#{i}", 'meeting_positions_id'=>pi)
    if prototype?
      assert_equal "new Insertion.Top('meeting_associated_records_list', \"\\u003Cli id='meeting_#{i}_positions_#{pi}'\\u003E\\n\\u003Ca href='#{root}/manage_position'\\u003EPositions\\u003C/a\\u003E - \\n\\u003Ca href='#{root}/edit_position/#{pi}'\\u003EZposition\\u003C/a\\u003E\\n\\u003Cform method='post' action='#{root}/remove_positions_from_meeting/#{i}?meeting_positions_id=#{pi}' onsubmit=\\\"new Ajax.Request('#{root}/remove_positions_from_meeting/#{i}?meeting_positions_id=#{pi}', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\\\"\\u003E\\n\\n\\n\\u003Cinput type='submit' value=Remove /\\u003E\\n\\u003C/form\\u003E\\n\\u003C/li\\u003E\\n\");\n$('meeting_positions_id').value = '';\n", res.body
    else
      assert_equal "$('#meeting_associated_records_list').prepend(\"\\u003Cli id='meeting_#{i}_positions_#{pi}'\\u003E\\n\\u003Ca href='#{root}/manage_position'\\u003EPositions\\u003C/a\\u003E - \\n\\u003Ca href='#{root}/edit_position/#{pi}'\\u003EZposition\\u003C/a\\u003E\\n\\u003Cform method='post' action='#{root}/remove_positions_from_meeting/#{i}?meeting_positions_id=#{pi}' onsubmit=\\\"$.post('#{root}/remove_positions_from_meeting/#{i}?meeting_positions_id=#{pi}', $(this).serialize(), function(data, textStatus){eval(data);}); return false;\\\"\\u003E\\n\\n\\n\\u003Cinput type='submit' value=Remove /\\u003E\\n\\u003C/form\\u003E\\n\\u003C/li\\u003E\\n\");\n$('#meeting_positions_id').val('');\n", res.body
    end
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 1, (p/:li).length
    assert_equal 'Positions', (p/"li a").first.inner_html
    assert_equal 'Zposition', (p/"li a").last.inner_html
    
    res = post_xhr(port, "#{root}/remove_positions_from_meeting/#{i}", 'meeting_positions_id'=>pi)
    if prototype?
      assert_equal "Element.remove('meeting_#{i}_positions_#{pi}');\n", res.body
    else
      assert_equal "$('#meeting_#{i}_positions_#{pi}').remove();\n", res.body
    end
    p = page(port, "#{root}/associations_meeting/#{i}")
    assert_equal 0, (p/:li).length
  end
end
