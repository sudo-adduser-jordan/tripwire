const DRAG_IGNORE =
  'input, select, textarea, button, a[href], label, summary, option, [contenteditable="true"], [role="button"], [tabindex]:not([tabindex="-1"])'

function clamp(value, low, high) {
  return Math.min(high, Math.max(low, value))
}

const DraggableModal = {
  mounted() {
    this.x = 0
    this.y = 0
    this.drag = null
    this.box = this.el.querySelector(":scope > .modal-box")
    this._syncTouch()

    this._onPointerDown = (ev) => this._start(ev)
    this._onPointerMove = (ev) => this._move(ev)
    this._onPointerUp = (ev) => this._end(ev)
    this._onBlur = () => this._end()
    this._onResize = () => this._reclamp()

    this.el.addEventListener("pointerdown", this._onPointerDown)
    window.addEventListener("blur", this._onBlur)
    window.addEventListener("resize", this._onResize)
  },

  updated() {
    const box = this.el.querySelector(":scope > .modal-box")
    if (box !== this.box) {
      this.box = box
      this._syncTouch()
    }
    this._apply()
  },

  destroyed() {
    this.endListeners()
    this.el.removeEventListener("pointerdown", this._onPointerDown)
    window.removeEventListener("blur", this._onBlur)
    window.removeEventListener("resize", this._onResize)
  },

  endListeners() {
    window.removeEventListener("pointermove", this._onPointerMove)
    window.removeEventListener("pointerup", this._onPointerUp)
    window.removeEventListener("pointercancel", this._onPointerUp)
  },

  _syncTouch() {
    if (!this.box) return
    this.box.style.touchAction = this.box.scrollHeight > this.box.clientHeight ? "pan-y" : "none"
  },

  _start(ev) {
    const box = this.box
    if (!box || ev.button !== 0 || this.drag) return
    if (ev.target.closest && ev.target.closest(DRAG_IGNORE)) return
    if (ev.target === box && (ev.offsetX >= box.clientWidth || ev.offsetY >= box.clientHeight)) return
    if (ev.pointerType === "touch" && box.scrollHeight > box.clientHeight) return

    ev.preventDefault()
    const rect = box.getBoundingClientRect()
    this.drag = {
      id: ev.pointerId,
      pointerX: ev.clientX,
      pointerY: ev.clientY,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      baseX: this.x,
      baseY: this.y,
    }
    this.el.classList.add("modal-dragging")
    window.addEventListener("pointermove", this._onPointerMove, { passive: false })
    window.addEventListener("pointerup", this._onPointerUp)
    window.addEventListener("pointercancel", this._onPointerUp)
  },

  _move(ev) {
    const drag = this.drag
    if (!drag || ev.pointerId !== drag.id) return
    ev.preventDefault()
    const bounds = this._bounds(drag)
    const left = clamp(drag.left + ev.clientX - drag.pointerX, bounds.minX, bounds.maxX)
    const top = clamp(drag.top + ev.clientY - drag.pointerY, bounds.minY, bounds.maxY)
    this.x = drag.baseX + left - drag.left
    this.y = drag.baseY + top - drag.top
    this._apply()
  },

  _end(ev) {
    if (!this.drag || (ev && ev.pointerId !== this.drag.id)) return
    this.drag = null
    this.el.classList.remove("modal-dragging")
    this.endListeners()
    this._syncTouch()
  },

  _bounds(drag) {
    const vw = document.documentElement.clientWidth
    const vh = document.documentElement.clientHeight
    return {
      minX: Math.min(0, vw - drag.width),
      maxX: Math.max(0, vw - drag.width),
      minY: Math.min(0, vh - drag.height),
      maxY: Math.max(0, vh - drag.height),
    }
  },

  _reclamp() {
    const box = this.box
    if (!box) return
    const vw = document.documentElement.clientWidth
    const vh = document.documentElement.clientHeight
    const rect = box.getBoundingClientRect()
    if (rect.width <= vw && rect.left < 0) this.x -= rect.left
    if (rect.width <= vw && rect.right > vw) this.x -= rect.right - vw
    if (rect.height <= vh && rect.top < 0) this.y -= rect.top
    if (rect.height <= vh && rect.bottom > vh) this.y -= rect.bottom - vh
    this._syncTouch()
    this._apply()
  },

  _apply() {
    if (!this.box) return
    const moved = this.x !== 0 || this.y !== 0
    this.box.style.transform = moved ? `translate3d(${this.x}px, ${this.y}px, 0)` : ""
  },
}

export default DraggableModal
