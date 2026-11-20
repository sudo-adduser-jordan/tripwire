const CardGrid = {
  mounted() {
    this.onKeyDown = (event) => this.handleKeyDown(event)
    this.onFocusIn = (event) => this.syncRoving(event.target)
    this.el.addEventListener("keydown", this.onKeyDown)
    this.el.addEventListener("focusin", this.onFocusIn)
  },

  updated() {
    const active = document.activeElement
    if (active && active.matches && active.matches("[data-card]") && this.el.contains(active)) {
      this.syncRoving(active)
    }
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeyDown)
    this.el.removeEventListener("focusin", this.onFocusIn)
  },

  cards() {
    return Array.from(this.el.querySelectorAll("[data-card]"))
  },

  handleKeyDown(event) {
    const target = event.target
    if (!target || !target.closest || !target.matches("[data-card]")) return

    const cards = this.cards()
    const index = cards.indexOf(target)
    if (index < 0) return

    if (event.key === "Enter" || event.key === " ") {
      const action = target.querySelector("[data-card-action]")
      if (!action) return
      event.preventDefault()
      action.click()
      return
    }

    let next = null

    if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = cards[index - 1]
    else if (event.key === "ArrowRight" || event.key === "ArrowDown") next = cards[index + 1]
    else if (event.key === "Home") next = cards[0]
    else if (event.key === "End") next = cards[cards.length - 1]
    else return

    event.preventDefault()
    if (next) next.focus()
  },

  syncRoving(card) {
    if (!card || !card.matches || !card.matches("[data-card]")) return
    this.cards().forEach((entry) => entry.setAttribute("tabindex", entry === card ? "0" : "-1"))
  },
}

export default CardGrid
