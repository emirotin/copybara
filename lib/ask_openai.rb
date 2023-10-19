# frozen_string_literal: true

require 'matrix'
require 'openai'

COMPLETIONS_MODEL = 'text-davinci-003'

MODEL_NAME = 'curie'

DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001".freeze
QUERY_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-query-001".freeze

MAX_SECTION_LEN = 500
SEPARATOR = "\n* "

COMPLETIONS_API_PARAMS = {
  # We use temperature of 0.0 because it gives the most predictable, factual answer.
  temperature: 0.0,
  max_tokens: 150,
  model: COMPLETIONS_MODEL
}.freeze

# AskOpenai class to handle all OpenAI API calls
class AskOpenai
  def initialize
    @openai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def ask(_question)
    separator_len = SEPARATOR.size

    "Answer #{separator_len}"
  end

  private

  def get_embedding(text, model)
    response = @openai_client.embeddings(
      parameters: {
        model:,
        input: text
      }
    )

    response.dig('data', 0, 'embedding')
  end

  def get_doc_embedding(text)
    get_embedding(text, DOC_EMBEDDINGS_MODEL)
  end

  def get_query_embedding(text)
    get_embedding(text, QUERY_EMBEDDINGS_MODEL)
  end

  # We could use cosine similarity or dot product to calculate the similarity between vectors.
  # In practice, we have found it makes little difference.
  def vector_similarity(arr1, arr2)
    Vector.elements(arr1).inner_product(Vector.elements(arr2))
  end
end
