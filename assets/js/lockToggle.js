const LockToggle = {
  mounted() {
    this.onClick = (ev) => {
      ev.preventDefault()
      const icon = this.el.querySelector("span[class*='hero-lock-']")
      const locked = this.el.dataset.locked !== "false"
      if (icon) {
        icon.classList.remove(locked ? "hero-lock-closed" : "hero-lock-open")
        icon.classList.add(locked ? "hero-lock-open" : "hero-lock-closed")
      }
      this.el.dataset.locked = locked ? "false" : "true"
      this.el.title = locked ? "Lock map" : "Unlock map"
    }
    this.el.addEventListener("click", this.onClick)
  },

  destroyed() {
    if (this.el) this.el.removeEventListener("click", this.onClick)
  },
}

export default LockToggle
