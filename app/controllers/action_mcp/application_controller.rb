module ActionMCP
  class ApplicationController < ActionController::Metal
    ActionController::API.without_modules(:StrongParameters, :ParamsWrapper).each do |left|
      include left
    end
  end
end
