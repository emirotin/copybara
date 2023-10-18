class AskController < ApplicationController
  def ask
    render json: { message: 'Hello World!', key: ENV['OPENAI_API_KEY'] }
  end
end
