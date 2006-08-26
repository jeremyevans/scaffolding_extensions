require 'test/unit'

# Functions have been added to test the scaffold and scaffold_all_models method
class Test::Unit::TestCase
  # Test the scaffold_all_models method using the same arguments as the method
  def self.test_scaffold_all_models(*models)
    ActionController::Base.parse_scaffold_all_models_options(*models).each do |model, options|
      test_scaffold(model, options)
    end
  end
  
  # Test the scaffold method using the same arguments as the method
  def self.test_scaffold(model, options = {})
    define_method("test_scaffold_#{model}") { scaffold_test(model, options) }
  end

  # Test that getting all display actions for the scaffold returns success
  def scaffold_test(model, options = {})
    methods = options[:only] ? @controller.class.normalize_scaffold_options(options[:only]) : @controller.class.default_scaffold_methods
    methods -= @controller.class.normalize_scaffold_options(options[:except]) if options[:except]
    methods.each do |action|
      assert_nothing_raised("Error requesting scaffolded action #{action} for model #{model.to_s.camelize}") do
        action = "#{action}_#{model}" if options[:suffix]
        get action
      end
      assert_response :success, "Response for scaffolded action #{action} for model #{model.to_s.camelize} not :success"
      # # The habtm scaffolds can't be tested without an id.  If the fixture for the
      # # main scaffolded class is loaded and it has id = 1, you may want to enable
      # # the following code for testing those scaffolds.
      # @controller.class.normalize_scaffold_options(options[:habtm]).each do |habtm|
      #   scaffold_habtm_test(model, habtm, 1)
      # end
    end
  end
  
  # Test the habtm scaffold for singular class, many class, and the specific id
  def scaffold_habtm_test(singular, many, id)
    action = "edit_#{singular}_#{many}", {:id=>id}
    assert_nothing_raised("Error requesting habtm scaffold #{action}") do
      get action
    end
    assert_response :success, "Response for habtm scaffold #{action} not :success"
  end
end
