# frozen_string_literal: true

require "#{Rails.root}/lib/ask_openai.rb"

# AskController
class AskController < ApplicationController
  def ask
    openai = AskOpenai.new
    answer = openai.ask(params[:question])
    render json: { answer: }
  end
end
