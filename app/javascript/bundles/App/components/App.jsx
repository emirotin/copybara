import React, { useState, useCallback } from "react";

const DEFAULT_QUESTION = "What is The Minimalist Entrepreneur about?";

const App = (props) => {
  const [question, setQuestion] = useState(DEFAULT_QUESTION);

  const onSubmit = useCallback((e) => {
    e.preventDefault();

    const csrfToken = document.querySelector("[name=csrf-token]").content;

    const { action, method } = e.target;
    const body = { question };
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
        console.log(answer);
      });
  }, []);

  return (
    <form action="/ask" method="post" onSubmit={onSubmit}>
      <textarea
        name="question"
        value={question}
        onChange={(e) => setQuestion(e.target.value)}
      />
      <div className="buttons">
        <button type="submit">Ask question</button>
        <button className="lucky-button" type="button">
          I'm feeling lucky
        </button>
      </div>
    </form>
  );
};

export default App;
