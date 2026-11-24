const ThemeSelect = {
  mounted() {
    this._onTheme = () => this._sync()
    this._onMode = () => this._sync()
    this._onClick = (event) => {
      const input = event.target.closest && event.target.closest("[data-mode-toggle]")
      if (!input) return
      input.dataset.phxMode = input.checked ? "dark" : "light"
    }
    window.addEventListener("phx:set-theme", this._onTheme)
    window.addEventListener("phx:set-mode", this._onMode)
    this.el.addEventListener("click", this._onClick)
    this._sync()
  },

  updated() {
    this._sync()
  },

  destroyed() {
    window.removeEventListener("phx:set-theme", this._onTheme)
    window.removeEventListener("phx:set-mode", this._onMode)
    this.el.removeEventListener("click", this._onClick)
  },

  _sync() {
    const active = localStorage.getItem("phx:theme") || "eve-online"
    const solid = localStorage.getItem("phx:solid") === "true"
    const font = localStorage.getItem("phx:font") || "eve"
    const mode =
      localStorage.getItem("phx:mode") === "dark" ? "dark" : "light"
    const toggle = this.el.querySelector("[data-solid-toggle]")
    const modeToggle = this.el.querySelector("[data-mode-toggle]")
    const fontSelect = this.el.querySelector("[data-font-select]")
    if (toggle) toggle.checked = solid
    if (modeToggle) {
      modeToggle.checked = mode === "dark"
      modeToggle.dataset.phxMode = mode
    }
    if (fontSelect) fontSelect.value = font
    for (const button of this.el.querySelectorAll("[data-phx-theme]")) {
      const selected = button.dataset.phxTheme === active
      button.classList.toggle("border-success", selected)
      button.classList.toggle("border-base-300", !selected)
      button.classList.toggle("ring-1", selected)
      button.classList.toggle("ring-success", selected)
      button.setAttribute("aria-pressed", selected ? "true" : "false")
    }
  },
}

export default ThemeSelect
