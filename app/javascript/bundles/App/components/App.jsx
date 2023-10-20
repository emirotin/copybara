import React, { useState, useCallback, useRef } from "react";

const DEFAULT_QUESTION = "What is The Minimalist Entrepreneur about?";

const LUCKY_QUESTIONS = [
  DEFAULT_QUESTION,
  "What is a minimalist entrepreneur?",
  "What is your definition of community?",
  "How do I decide what kind of business I should start?",
];

const App = () => {
  const formRef = useRef();
  const [question, setQuestion] = useState(DEFAULT_QUESTION);
  const [answer, setAnswer] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  const onSubmit = useCallback((e, questionOverride) => {
    e.preventDefault?.();

    const questionToAsk = questionOverride || question;

    if (!questionToAsk) {
      return;
    }

    setAnswer(null);
    setIsLoading(true);
    setError(null);

    const csrfToken = document.querySelector("[name=csrf-token]").content;

    const { action, method } = e.target;
    const body = { question: questionToAsk };
    fetch(action, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-TOKEN": csrfToken,
      },
      body: JSON.stringify(body),
    })
      .then((response) => response.json())
      .then((data) => {
        const { answer } = data;
        setAnswer(answer);
      })
      .catch((error) => {
        setError(error.message || "Something went wrong");
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  return (
    <form action="/ask" method="post" onSubmit={onSubmit} ref={formRef}>
      <textarea
        name="question"
        value={question}
        onChange={(e) => setQuestion(e.target.value)}
      />
      {error && <div className="error">{error}</div>}
      {isLoading && <p>Loading...</p>}
      {answer !== null ? (
        <div className="answer-container">
          <strong>Answer:</strong>
          <div>{answer}</div>
          <button onClick={() => setAnswer(null)}>Ask another question</button>
        </div>
      ) : (
        <div className="buttons">
          <button type="submit">Ask question</button>
          <button
            className="lucky-button"
            type="button"
            onClick={() => {
              const candidateQuestions = LUCKY_QUESTIONS.filter(
                (candidateQuestion) => candidateQuestion !== question
              );
              const randomIndex = Math.floor(
                Math.random() * candidateQuestions.length
              );
              const luckyQuestion = candidateQuestions[randomIndex];
              setQuestion(luckyQuestion);
              setTimeout(
                () => onSubmit({ target: formRef.current }, luckyQuestion),
                50
              );
            }}
          >
            I'm feeling lucky
          </button>
        </div>
      )}
    </form>
  );
};

export default App;
