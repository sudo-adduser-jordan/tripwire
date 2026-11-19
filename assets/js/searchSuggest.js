const SearchSuggest = {
  mounted() {
    this.input = this.el.querySelector("#system-search")
    this.active = -1
    if (!this.input) return

    this.onKeyDown = (ev) => {
      if (ev.key !== "ArrowDown" && ev.key !== "ArrowUp" && ev.key !== "Enter" && ev.key !== "Escape") return
      const items = this.menuItems()
      if (ev.key === "Escape") {
        this.active = -1
        this.highlight(items)
        return
      }
      if (!items.length) return
      if (ev.key === "Enter") {
        if (this.active >= 0 && this.active < items.length) {
          ev.preventDefault()
          const target = items[this.active]
          this.active = -1
          target.click()
        }
        return
      }
      ev.preventDefault()
      const dir = ev.key === "ArrowDown" ? 1 : -1
      this.active = (this.active + dir + items.length) % items.length
      this.highlight(items)
      const current = items[this.active]
      if (current && current.scrollIntoView) current.scrollIntoView({ block: "nearest" })
    }

    this.input.addEventListener("keydown", this.onKeyDown)
  },

  updated() {
    const items = this.menuItems()
    this.active = items.length ? 0 : -1
    this.highlight(items)
  },

  destroyed() {
    if (this.input && this.onKeyDown) this.input.removeEventListener("keydown", this.onKeyDown)
  },

  menuItems() {
    return Array.from(this.el.querySelectorAll("[data-suggest-item]"))
  },

  highlight(items) {
    items.forEach((item, i) => {
      item.classList.toggle("bg-base-300", i === this.active)
    })
  },
}

export default SearchSuggest
