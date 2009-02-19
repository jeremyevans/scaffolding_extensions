require 'test/unit'

# Simple test framework to check that public facing pages without an id respond successfully
#
# This is only a basic check, it does not check that all form submittals work, as that
# requires that you choose an object to test.  If you want to be sure that all parts of
# Scaffolding Extensions work with your applications, you should extend the tests here to do so.
class Test::Unit::TestCase
  # Test the scaffold_all_models method using the same arguments as the method
  def self.test_scaffold_all_models(options = {})
    ActionController::Base.send(:scaffold_all_models_parse_options, options).each{|model, options| test_scaffold(model, options)}
  end
  
  # Test the scaffold method using the same arguments as the method
  def self.test_scaffold(model, options = {})
    define_method("test_scaffold_#{model.scaffold_name}"){scaffold_test(model, options)}
  end

  # Default scaffold session hash to use.
  def scaffold_session
    {}
  end

  # Test that getting all display actions for the scaffold returns success
  def scaffold_test(model, options = {})
    klass = @controller.class
    methods = options[:only] ? Array(options[:only]) : ScaffoldingExtensions::DEFAULT_METHODS
    methods -= Array(options[:except]) if options[:except]
    methods.each do |action|
      assert_nothing_raised("Error requesting scaffolded action #{action} for model #{model.name}") do
        get "#{action}_#{model.scaffold_name}", nil, scaffold_session
      end
      assert_response :success, "Response for scaffolded action #{action} for model #{model.name} not :success"
    end
  end
  
  # Test the habtm scaffold for singular class, many class, and the specific id
  def scaffold_habtm_test(model, association, id)
    action = "edit_#{model.scaffold_name}_#{association}", {:id=>id}
    assert_nothing_raised("Error requesting habtm scaffold #{action}"){get action}
    assert_response :success, "Response for habtm scaffold #{action} not :success"
  end
end
