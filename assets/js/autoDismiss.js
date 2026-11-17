const AutoDismiss = {
  mounted() {
    this._arm()
  },

  updated() {
    this._arm()
  },

  destroyed() {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
  },

  _arm() {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
    if (this.el.hasAttribute("data-persist")) return
    const ms = parseInt(this.el.dataset.timeout || "4000", 10)
    if (!ms || ms <= 0) return
    this._timer = setTimeout(() => {
      this._timer = null
      this.pushEvent("lv:clear-flash", { key: this.el.dataset.flashKind })
      this.el.remove()
    }, ms)
  },
}

export default AutoDismiss
