const DRAG_THRESHOLD = 4
const VIEW_W = 1000
const VIEW_H = 700
const PAD_Y = 40

const MapDrag = {
  mounted() {
    this.svg = this.el
    if (!this.svg) return
    this.panning = false
    this.suppressed = false
    this.startClient = null
    this.origin = null
    this.scale = null
    this._top = null
    this._raf = 0
    this._pending = null
    const at = this.viewOrigin()
    this.ox = at.x
    this.oy = at.y
    this._top = this.topBound()

    this.onPointerDown = (ev) => {
      if (ev.target.closest("g[data-system-id]")) return
      // Cache the screen-to-SVG scale once per drag: it only depends on the
      // rendered size, not the pan origin, so per-move getScreenCTM() lookups
      // (which force layout) are unnecessary and caused the stutter.
      const ctm = this.svg.getScreenCTM()
      if (!ctm || !ctm.a || !ctm.d) return
      this.panning = true
      this.suppressed = false
      this.startClient = { x: ev.clientX, y: ev.clientY }
      this.scale = { x: ctm.a, y: ctm.d }
      this.origin = this.viewOrigin()
      this._top = this.topBound()
      ev.preventDefault()
    }

    this.onPointerMove = (ev) => {
      if (!this.panning || !this.startClient) return
      const dx = (ev.clientX - this.startClient.x) / this.scale.x
      const dy = (ev.clientY - this.startClient.y) / this.scale.y
      if (!this.suppressed && Math.hypot(dx, dy) > DRAG_THRESHOLD) this.suppressed = true
      this._pending = this.clampView(this.origin.x - dx, this.origin.y - dy)
      // Coalesce moves to one viewBox write per frame.
      if (!this._raf) {
        this._raf = requestAnimationFrame(() => {
          this._raf = 0
          if (this._pending) {
            const next = this._pending
            this._pending = null
            this.setView(next.x, next.y)
          }
        })
      }
      ev.preventDefault()
    }

    this.onPointerUp = (_ev) => {
      this.panning = false
      this.startClient = null
      if (this._raf) {
        cancelAnimationFrame(this._raf)
        this._raf = 0
        if (this._pending) {
          const next = this._pending
          this._pending = null
          this.setView(next.x, next.y)
        }
      }
    }

    this.onClick = (ev) => {
      if (!this.suppressed) return
      this.suppressed = false
      ev.stopPropagation()
      ev.preventDefault()
    }

    this.handleEvent("reset-pan", ({ x, y }) => {
      this._top = this.topBound()
      const next = this.clampView(x, y)
      this.setView(next.x, next.y)
    })

    this.svg.addEventListener("pointerdown", this.onPointerDown)
    this.svg.addEventListener("click", this.onClick, true)
    window.addEventListener("pointermove", this.onPointerMove, { passive: false })
    window.addEventListener("pointerup", this.onPointerUp)
  },

  updated() {
    this._top = this.topBound()
    // Re-assert the client pan after LiveView patches, but skip the write
    // when the viewBox already matches to avoid redundant layout.
    const at = this.viewOrigin()
    if (at.x !== this.ox || at.y !== this.oy) this.setView(this.ox, this.oy)
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onPointerDown)
    this.svg.removeEventListener("click", this.onClick, true)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
  },

  viewOrigin() {
    const parts = (this.svg.getAttribute("viewBox") || "0 0 1000 700").split(/\s+/).map(Number)
    return { x: parts[0] || 0, y: parts[1] || 0 }
  },

  setView(x, y) {
    this.ox = x
    this.oy = y
    this.svg.setAttribute("viewBox", `${x} ${y} ${VIEW_W} ${VIEW_H}`)
  },

  clampView(x, y) {
    const top = this._top
    return { x, y: top === null || top === undefined ? y : Math.max(y, top) }
  },

  topBound() {
    const nodes = this.svg.querySelectorAll("g[data-system-id]")
    if (!nodes.length) return null
    let min = Infinity
    nodes.forEach((node) => {
      const [_x, y] = parseTransform(node.getAttribute("transform"))
      if (y < min) min = y
    })
    return min - PAD_Y
  },
}

const ChartMount = {
  mounted() {
    const name = this.el.dataset.chartFn
    const init = name && window.TripwireCharts && window.TripwireCharts[name]
    if (typeof init === "function") init()
  },
}

function parseTransform(transform) {
  const match = /translate\(([-\d.]+),\s*([-\d.]+)\)/.exec(transform || "")
  return match ? [parseFloat(match[1]), parseFloat(match[2])] : [0, 0]
}

export { MapDrag as default, ChartMount }
