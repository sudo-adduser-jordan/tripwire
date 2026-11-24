const SettingsShortcut = {
  mounted() {
    this._onKeyDown = (event) => {
      if (event.key !== "Escape" || event.repeat || event.defaultPrevented) return
      const target = event.target
      if (target && target.closest) {
        if (target.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"])')) return
        if (target.closest(".modal")) return
      }
      this.pushEvent("toggle-settings", {})
    }
    window.addEventListener("keydown", this._onKeyDown)
  },

  destroyed() {
    if (this._onKeyDown) window.removeEventListener("keydown", this._onKeyDown)
  },
}

export default SettingsShortcut
