const DRAG_THRESHOLD = 4
const FREE_LIMIT = 5000
const VIEW_W = 1000
const VIEW_H = 700
const PAD_Y = 40

const MapDrag = {
  mounted() {
    this.svg = this.el
    if (!this.svg) return
    this.panning = false
    this.suppressed = false
    this.start = null
    this.origin = null
    const at = this.viewOrigin()
    this.ox = at.x
    this.oy = at.y

    this.onPointerDown = (ev) => {
      if (ev.target.closest("g[data-system-id]")) return
      const pt = this.toSvgPoint(ev)
      if (!pt) return
      this.panning = true
      this.suppressed = false
      this.start = pt
      this.origin = this.viewOrigin()
      ev.preventDefault()
    }

    this.onPointerMove = (ev) => {
      if (!this.panning) return
      const pt = this.toSvgPoint(ev)
      if (!pt) return
      const dx = pt.x - this.start.x
      const dy = pt.y - this.start.y
      if (!this.suppressed && Math.hypot(dx, dy) > DRAG_THRESHOLD) this.suppressed = true
      const next = this.clampView(this.origin.x - dx, this.origin.y - dy)
      this.setView(next.x, next.y)
      ev.preventDefault()
    }

    this.onPointerUp = (_ev) => {
      this.panning = false
    }

    this.onClick = (ev) => {
      if (!this.suppressed) return
      this.suppressed = false
      ev.stopPropagation()
      ev.preventDefault()
    }

    this.handleEvent("reset-pan", ({ x, y }) => {
      const next = this.clampView(x, y)
      this.setView(next.x, next.y)
    })

    this.svg.addEventListener("pointerdown", this.onPointerDown)
    this.svg.addEventListener("click", this.onClick, true)
    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
  },

  updated() {
    this.setView(this.ox, this.oy)
  },

  destroyed() {
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onPointerDown)
    this.svg.removeEventListener("click", this.onClick, true)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
  },

  toSvgPoint(ev) {
    const ctm = this.svg.getScreenCTM()
    if (!ctm) return null
    return {
      x: (ev.clientX - ctm.e) / ctm.a,
      y: (ev.clientY - ctm.f) / ctm.d,
    }
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
    const top = this.topBound()
    return {
      x: Math.max(-FREE_LIMIT, Math.min(x, FREE_LIMIT)),
      y:
        top === null
          ? Math.max(-FREE_LIMIT, Math.min(y, FREE_LIMIT))
          : Math.min(Math.max(y, -FREE_LIMIT), top),
    }
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
    this._initChart()
  },
  updated() {
    this._initChart()
  },
  _initChart() {
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
