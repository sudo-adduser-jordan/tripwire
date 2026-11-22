const NotesComposer = {
  mounted() {
    this._onKeyDown = (event) => {
      if (event.key !== "Escape" || this.el.dataset.open !== "true") return
      const toggle = document.getElementById("note-compose-toggle")
      if (toggle) toggle.click()
    }

    this.el.addEventListener("keydown", this._onKeyDown)
    this._focusIfOpened()
  },

  updated() {
    this._focusIfOpened()
  },

  destroyed() {
    this.el.removeEventListener("keydown", this._onKeyDown)
  },

  _focusIfOpened() {
    const open = this.el.dataset.open === "true"
    if (open && !this._wasOpen) {
      const textarea = this.el.querySelector("textarea")
      if (textarea) textarea.focus()
    }
    this._wasOpen = open
  },
}

export default NotesComposer
