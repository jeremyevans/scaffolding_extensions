class AdminController < Ramaze::Controller
  map '/admin'
  scaffold_all_models
end
