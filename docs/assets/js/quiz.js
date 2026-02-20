document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".quiz button").forEach(button => {
    button.addEventListener("click", event => {
      const quiz = event.target.closest(".quiz")
      const correct = quiz.dataset.answer
      const chosen = event.target.dataset.option
      const feedback = quiz.querySelector(".feedback")

      // Remove classes anteriores
      quiz.querySelectorAll("button").forEach(btn => {
        btn.classList.remove("selected", "correct", "incorrect")
      })

      // Marca a opção selecionada
      event.target.classList.add("selected")

      // Verifica resposta
      if (chosen === correct) {
        event.target.classList.add("correct")
        feedback.textContent = "✔️ Correto!"
        feedback.style.color = "green"
      } else {
        event.target.classList.add("incorrect")
        feedback.textContent = "❌ Tente novamente."
        feedback.style.color = "red"
      }
    })
  })
})
