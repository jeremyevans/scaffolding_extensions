class CleanUpARGarbage
  def initialize(app, opts={})
    @app = app
  end
  def call(env)
    res = @app.call(env)
    ActiveRecord::Base.clear_active_connections!
    res
  end
end
