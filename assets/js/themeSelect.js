const ThemeSelect = {
  mounted() {
    this._onTheme = () => this._sync()
    window.addEventListener("phx:set-theme", this._onTheme)
    this._sync()
  },

  updated() {
    this._sync()
  },

  destroyed() {
    window.removeEventListener("phx:set-theme", this._onTheme)
  },

  _sync() {
    const active = localStorage.getItem("phx:theme") || "phoenix"
    for (const button of this.el.querySelectorAll("[data-phx-theme]")) {
      const selected = button.dataset.phxTheme === active
      button.classList.toggle("ring-2", selected)
      button.classList.toggle("ring-success", selected)
      button.classList.toggle("ring-offset-2", selected)
      button.classList.toggle("ring-offset-base-100", selected)
      button.setAttribute("aria-pressed", selected ? "true" : "false")
    }
  },
}

export default ThemeSelect
