const DRAG_THRESHOLD = 4
const FREE_LIMIT = 800
const VIEW_W = 1000
const VIEW_H = 700
const NODE_W = 120
const NODE_H = 88
const PAD_X = 160
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
    return {
      x: this.clampAxis(x, this.axisBounds("x", NODE_W, VIEW_W, PAD_X)),
      y: this.clampAxis(y, this.axisBounds("y", NODE_H, VIEW_H, PAD_Y)),
    }
  },

  axisBounds(axis, nodeSize, viewSize, pad) {
    const nodes = this.svg.querySelectorAll("g[data-system-id]")
    if (!nodes.length) return null
    let min = Infinity
    let max = -Infinity
    nodes.forEach((node) => {
      const [x, y] = parseTransform(node.getAttribute("transform"))
      const v = axis === "x" ? x : y
      if (v < min) min = v
      if (v > max) max = v
    })
    const low = min - pad
    const high = max + nodeSize + pad - viewSize
    return { low: Math.min(low, high), high: Math.max(low, high) }
  },

  clampAxis(value, bounds) {
    if (!bounds) return Math.max(-FREE_LIMIT, Math.min(value, FREE_LIMIT))
    return Math.max(bounds.low, Math.min(value, bounds.high))
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
