class AskController < ApplicationController
  def ask
    render json: { message: 'Hello World!' }
  end
end
