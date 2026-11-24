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
    const active = localStorage.getItem("phx:theme") || "eve-online"
    const solid = localStorage.getItem("phx:solid") === "true"
    const font = localStorage.getItem("phx:font") || "eve"
    const toggle = this.el.querySelector("[data-solid-toggle]")
    const fontSelect = this.el.querySelector("[data-font-select]")
    if (toggle) toggle.checked = solid
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
