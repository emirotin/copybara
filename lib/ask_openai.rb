# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'matrix'
require 'openai'
require 'csv'

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

OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY')
  config.organization_id = ENV.fetch('OPENAI_ORG_ID')
end

# rubocop:disable Metrics/ClassLength
# AskOpenai class to handle all OpenAI API calls
class AskOpenai
  extend T::Sig

  def initialize
    @openai_client = OpenAI::Client.new
    @separator_len = SEPARATOR.size
  end

  sig { params(question: String).returns(String) }
  def ask(question)
    q = question.strip
    q << '?' unless q.end_with?('?')

    # previous_question = Question.objects.filter(question=question_asked).first()

    # if previous_question:
    #     print("previously asked and answered: " + previous_question.answer)
    #     previous_question.ask_count = previous_question.ask_count + 1
    #     previous_question.save()
    #     return JsonResponse({ "question": previous_question.question, "answer": previous_question.answer, "id": previous_question.pk })

    pages = load_sections('assets/book.pdf.pages.csv')
    document_embeddings = load_embeddings('assets/book.pdf.embeddings.csv')
    answer, _context = answer_query_with_context(q, document_embeddings, pages)

    # project_uuid = '6314e4df'
    # voice_uuid = '0eb3a3f1'

    # question = Question(question=question_asked, answer=answer, context=context)
    # question.save()

    # return JsonResponse({ "question": question.question, "answer": answer, "id": question.pk })
    answer
  end

  private

  sig { params(text: String, model: String).returns(T::Array[Float]) }
  def get_embedding(text, model)
    response = @openai_client.embeddings(
      parameters: {
        model:,
        input: text
      }
    )

    T.let(response.dig('data', 0, 'embedding'), T::Array[Float])
  end

  # sig { params(text: String, model: String).returns(T::Array[Float]) }
  # def get_doc_embedding(text)
  #   get_embedding(text, DOC_EMBEDDINGS_MODEL)
  # end

  sig { params(text: String).returns(T::Array[Float]) }
  def get_query_embedding(text)
    get_embedding(text, QUERY_EMBEDDINGS_MODEL)
  end

  sig { params(arr1: T::Array[Float], arr2: T::Array[Float]).returns(Float) }
  def vector_similarity(arr1, arr2)
    # We could use cosine similarity or dot product to calculate the similarity between vectors.
    # In practice, we have found it makes little difference.
    Vector.elements(arr1).inner_product(Vector.elements(arr2))
  end

  sig { params(query: String, contexts: T::Hash[String, T::Array[Float]]).returns(T::Array[[Float, String]]) }
  # Find the query embedding for the supplied query,
  # and compare it against all of the pre-calculated document embeddings
  # to find the most relevant sections.
  # Return the list of document sections, sorted by relevance in descending order.
  def order_document_sections_by_query_similarity(query, contexts)
    query_embedding = get_query_embedding(query)

    similarities = contexts.keys.map do |doc_section_title|
      doc_embedding = contexts[doc_section_title]
      [vector_similarity(query_embedding, T.must(doc_embedding)), doc_section_title]
    end

    similarities.sort_by { |similarity, _doc_index| -similarity }
  end

  sig { params(filename: String).returns(T::Hash[String, T::Array[Float]]) }
  # Read the document embeddings and their keys from a CSV.
  # filename is the path to a CSV with exactly these named columns:
  #    "title", "0", "1", ... up to the length of the embedding vectors.
  def load_embeddings(filename)
    table = CSV.read(File.join(File.dirname(__FILE__), filename))
    headers = table.shift
    raise 'CSV must have "title" as the first column' unless headers && headers[0] == 'title'

    table.each_with_object({}) do |row, hash|
      title = row.shift
      hash[title] = row.map(&:to_f)
    end
  end

  sig { params(filename: String).returns(T::Array[{ title: String, content: String, tokens: Integer }]) }
  # Read the document sections and their tokens.
  def load_sections(filename)
    table = CSV.read(File.join(File.dirname(__FILE__), filename))
    headers = table.shift
    raise 'CSV must have "title" as the first column' unless headers && headers[0] == 'title'

    table.map do |row|
      title, content, tokens = row
      { title: T.must(title), content: T.must(content), tokens: tokens.to_i }
    end
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  sig do
    params(question: String, context_embeddings: T::Hash[String, T::Array[Float]],
           pages: T::Array[{ title: String, content: String, tokens: Integer }]).returns(T::Array[String])
  end
  def pick_prompt_sections(question, context_embeddings, pages)
    most_relevant_document_sections = order_document_sections_by_query_similarity(question, context_embeddings)

    chosen_sections = T.let([], T::Array[String])
    chosen_sections_len = 0

    most_relevant_document_sections.each do |_, doc_section_title|
      document_section = T.must(pages.find { |page| page[:title] == doc_section_title })

      chosen_sections_len += document_section[:tokens] + @separator_len

      if chosen_sections_len > MAX_SECTION_LEN
        space_left = MAX_SECTION_LEN - chosen_sections_len - @separator_len
        chosen_sections << SEPARATOR + T.must(T.must(document_section[:content])[0...space_left])
      else
        chosen_sections << SEPARATOR + T.must(document_section[:content])
      end
    end

    chosen_sections
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Layout/LineLength
  sig { returns(T::Array[String]) }
  def prompt_pre
    [
      "Sahil Lavingia is the founder and CEO of Gumroad, and the author of the book The Minimalist Entrepreneur (also known as TME). These are questions and answers by him. Please keep your answers to three sentences maximum, and speak in complete sentences. Stop speaking once your point is made.\n\nContext that may be useful, pulled from The Minimalist Entrepreneur:",

      "Q: How to choose what business to start?\n\nA: First off don't be in a rush. Look around you, see what problems you or other people are facing, and solve one of these problems if you see some overlap with your passions or skills. Or, even if you don't see an overlap, imagine how you would solve that problem anyway. Start super, super small.",
      "Q: Q: Should we start the business on the side first or should we put full effort right from the start?\n\nA:   Always on the side. Things start small and get bigger from there, and I don't know if I would ever “fully” commit to something unless I had some semblance of customer traction. Like with this product I'm working on now!",
      "Q: Should we sell first than build or the other way around?\n\nA: I would recommend building first. Building will teach you a lot, and too many people use “sales” as an excuse to never learn essential skills like building. You can't sell a house you can't build!",
      "Q: Andrew Chen has a book on this so maybe touché, but how should founders think about the cold start problem? Businesses are hard to start, and even harder to sustain but the latter is somewhat defined and structured, whereas the former is the vast unknown. Not sure if it's worthy, but this is something I have personally struggled with\n\nA: Hey, this is about my book, not his! I would solve the problem from a single player perspective first. For example, Gumroad is useful to a creator looking to sell something even if no one is currently using the platform. Usage helps, but it's not necessary.",
      "Q: What is one business that you think is ripe for a minimalist Entrepreneur innovation that isn't currently being pursued by your community?\n\nA: I would move to a place outside of a big city and watch how broken, slow, and non-automated most things are. And of course the big categories like housing, transportation, toys, healthcare, supply chain, food, and more, are constantly being upturned. Go to an industry conference and it's all they talk about! Any industry…",
      "Q: How can you tell if your pricing is right? If you are leaving money on the table\n\nA: I would work backwards from the kind of success you want, how many customers you think you can reasonably get to within a few years, and then reverse engineer how much it should be priced to make that work.",
      "Q: Why is the name of your book 'the minimalist entrepreneur' \n\nA: I think more people should start businesses, and was hoping that making it feel more “minimal” would make it feel more achievable and lead more people to starting-the hardest step.",
      "Q: How long it takes to write TME\n\nA: About 500 hours over the course of a year or two, including book proposal and outline.",
      "Q: What is the best way to distribute surveys to test my product idea\n\nA: I use Google Forms and my email list / Twitter account. Works great and is 100% free.",
      "Q: How do you know, when to quit\n\nA: When I'm bored, no longer learning, not earning enough, getting physically unhealthy, etc… loads of reasons. I think the default should be to “quit” and work on something new. Few things are worth holding your attention for a long period of time."
    ]
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Layout/LineLength

  sig do
    params(question: String, context_embeddings: T::Hash[String, T::Array[Float]],
           pages: T::Array[{ title: String, content: String, tokens: Integer }]).returns([String, String])
  end
  # Fetch relevant embeddings
  def construct_prompt(question, context_embeddings, pages)
    chosen_sections = pick_prompt_sections(question, context_embeddings, pages)

    header, *questions = prompt_pre

    [
      "#{header}\n#{chosen_sections.join('')}#{T.must(questions).join("\n\n\n")}\n\n\nQ: #{question}\n\nA: ",
      chosen_sections.join('')
    ]
  end

  sig do
    params(question: String, context_embeddings: T::Hash[String, T::Array[Float]],
           pages: T::Array[{ title: String, content: String, tokens: Integer }]).returns([String, String])
  end
  def answer_query_with_context(question, context_embeddings, pages)
    prompt, context = construct_prompt(
      question, context_embeddings, pages
    )

    response = @openai_client.completions(parameters: COMPLETIONS_API_PARAMS.merge({ prompt: }))

    [T.let(response.dig('choices', 0, 'text'), String).strip, context]
  end
end
# rubocop:enable Metrics/ClassLength
