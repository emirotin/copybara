# frozen_string_literal: true

require "#{Rails.root}/lib/ask_openai.rb"

# AskController
class AskController < ApplicationController
  def ask
    openai = AskOpenai.new
    question = params[:question] || 'What is a minimalist entrepreneur?'
    answer = openai.ask(question)
    render json: { answer: }
  end
end
