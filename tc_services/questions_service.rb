class QuestionsService
  def initialize(user:)
    @user = user
  end

  def list(company_id: nil, filter_tags: nil)
    query = Question.select(:id, :question, :user_id,
                            "questions.company_list_id as company_id")
                    .joins("LEFT JOIN answers on answers.question_id = questions.id")
                    .select("COUNT(DISTINCT (
                              case when answers.company_list_id = #{company_id} and
                                   (answers.verified = true or answers.user_id = #{@user.id})
                                   then answers.id
                              end
                             )) as answers_count")
                    .joins("LEFT JOIN question_tags on question_tags.question_id = questions.id")
                    .select("ARRAY_REMOVE(ARRAY_AGG(DISTINCT tag), null) as tags")
                    .where(company_list_id: [nil, company_id], verified: true)
                    .group("questions.id")
    query = query.where(question_tags: {tag: filter_tags}) if filter_tags

    query.to_a
  end

  def list_with_top_answer(company_id: nil, filter_tags: nil)
    questions = list(company_id: company_id, filter_tags: filter_tags)

    formatted_questions = questions.map do |question|
      top_answer = Answer.includes(:position, :function, :city)
                         .where(question_id: question.id, company_list_id: company_id, verified: true)
                         .order("answer_upvotes_count DESC, id DESC")
                         .limit(1)
                         .first
      top_answer = AnswerSerializer.new(top_answer).as_json if top_answer
      question.attributes.symbolize_keys.merge(top_answer: top_answer)
    end

    formatted_questions
  end

  def all_questions_answered?(company_list_id: nil)
    question_ids = Question.where(company_list_id: [nil, company_list_id], verified: true).pluck(:id)
    answered_question_ids = Answer.where(user_id: @user.id, company_list_id: company_list_id)
                                  .pluck(:question_id)

    return true if (question_ids - answered_question_ids).empty?

    false
  end

  def user_questions
    company_list_ids = @user.companies
                            .complete
                            .pluck(:company_list_id)
                            .uniq

    user_questions = []
    company_list_ids.each do |company_list_id|
      questions = Question.select(:id)
                          .joins("LEFT JOIN question_tags on question_tags.question_id = questions.id")
                          .select("ARRAY_REMOVE(ARRAY_AGG(DISTINCT tag), null) as tags")
                          .where(company_list_id: [nil, company_list_id], verified: true)
                          .group("questions.id")

      answered_question_ids = Answer.where(user_id: @user.id, company_list_id: company_list_id).pluck(:question_id).uniq

      user_questions << {
        company_id: company_list_id,
        questions: questions.map {|q|
          {id: q.id, tags: q.tags, answered: answered_question_ids.include?(q.id)}
        }
      }
    end

    user_questions
  end

  def unanswered_questions
    company_list_ids = @user.companies
                            .complete
                            .pluck(:company_list_id)
                            .uniq

    unanswered_questions = []
    company_list_ids.each do |company_list_id|
      questions = Question.select(:id)
                          .joins("LEFT JOIN question_tags on question_tags.question_id = questions.id")
                          .select("ARRAY_REMOVE(ARRAY_AGG(DISTINCT tag), null) as tags")
                          .where(company_list_id: [nil, company_list_id], verified: true)
                          .group("questions.id")

      answered_question_ids = Answer.where(user_id: @user.id, company_list_id: company_list_id).pluck(:question_id).uniq
      unanswered = questions.select {|q| answered_question_ids.exclude? q.id }

      unanswered_questions << {company_id: company_list_id, questions: unanswered.as_json}
    end

    unanswered_questions
  end

  def answered_questions
    Answer.select("company_list_id as company_id", "ARRAY_AGG(DISTINCT question_id) as question_ids")
          .where(user_id: @user.id)
          .group(:company_list_id)
  end
end
