const DRAG_THRESHOLD = 4
const VIEW_W = 1000
const VIEW_H = 700
const PAD_Y = 40
const MIN_ZOOM = 0.25
const MAX_ZOOM = 4
const ZOOM_STEP = 1.25
const WHEEL_SENS = 0.0015

function clampZoom(z) {
    return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, z))
}

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
    this.zoom = 1
    const at = this.viewBox()
    this.ox = at.x
    this.oy = at.y
    if (at.w) this.zoom = clampZoom(VIEW_W / at.w)
    this._top = this.topBound()
    this.updateZoomLabel()

    this.onPointerDown = (ev) => {
      if (ev.target.closest("g[data-system-id]")) return
      const ctm = this.svg.getScreenCTM()
      if (!ctm || !ctm.a || !ctm.d) return
      this.panning = true
      this.suppressed = false
      this.startClient = { x: ev.clientX, y: ev.clientY }
      this.scale = { x: ctm.a, y: ctm.d }
      this.origin = { x: this.ox, y: this.oy }
      this._top = this.topBound()
      ev.preventDefault()
    }

    this.onPointerMove = (ev) => {
      if (!this.panning || !this.startClient) return
      const dx = (ev.clientX - this.startClient.x) / this.scale.x
      const dy = (ev.clientY - this.startClient.y) / this.scale.y
      if (!this.suppressed && Math.hypot(dx, dy) > DRAG_THRESHOLD) this.suppressed = true
      this._pending = this.clampView(this.origin.x - dx, this.origin.y - dy)
      if (!this._raf) {
        this._raf = requestAnimationFrame(() => {
          this._raf = 0
          if (this._pending) {
            const next = this._pending
            this._pending = null
            this.setView(next.x, next.y, this.zoom)
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
          this.setView(next.x, next.y, this.zoom)
        }
      }
    }

    this.onClick = (ev) => {
      if (!this.suppressed) return
      this.suppressed = false
      ev.stopPropagation()
      ev.preventDefault()
    }

    this.onWheel = (ev) => {
      ev.preventDefault()
      let dy = ev.deltaY
      if (ev.deltaMode === 1) dy *= 33
      if (!dy) return
      const factor = Math.exp(-dy * WHEEL_SENS)
      const rect = this.svg.getBoundingClientRect()
      if (!rect.width || !rect.height) return
      const w = VIEW_W / this.zoom
      const h = VIEW_H / this.zoom
      const fx = (ev.clientX - rect.left) / rect.width
      const fy = (ev.clientY - rect.top) / rect.height
      this.zoomAt(this.ox + fx * w, this.oy + fy * h, factor)
    }

    this.onZoomIn = () => this.zoomBy(ZOOM_STEP)
    this.onZoomOut = () => this.zoomBy(1 / ZOOM_STEP)
    this.onZoomReset = () => this.setView(this.ox, this.oy, 1)

    this.onKeyDown = (ev) => {
      if (ev.key === "+" || ev.key === "=") {
        ev.preventDefault()
        this.zoomBy(ZOOM_STEP)
      } else if (ev.key === "-" || ev.key === "_") {
        ev.preventDefault()
        this.zoomBy(1 / ZOOM_STEP)
      } else if (ev.key === "0") {
        ev.preventDefault()
        this.setView(this.ox, this.oy, 1)
      }
    }

    this.onDblClick = (ev) => {
      ev.preventDefault()
      const rect = this.svg.getBoundingClientRect()
      const w = VIEW_W / this.zoom
      const h = VIEW_H / this.zoom
      const fx = rect.width ? (ev.clientX - rect.left) / rect.width : 0.5
      const fy = rect.height ? (ev.clientY - rect.top) / rect.height : 0.5
      this.zoomAt(this.ox + fx * w, this.oy + fy * h, ev.shiftKey ? 1 / ZOOM_STEP : ZOOM_STEP)
    }

    this.handleEvent("reset-pan", ({ x, y }) => {
      this._top = this.topBound()
      const next = this.clampView(x, y)
      this.setView(next.x, next.y, 1)
    })

    this.handleEvent("map-zoom", ({ zoom }) => {
      this.setView(this.ox, this.oy, zoom)
    })

    this.svg.addEventListener("pointerdown", this.onPointerDown)
    this.svg.addEventListener("click", this.onClick, true)
    this.svg.addEventListener("wheel", this.onWheel, { passive: false })
    this.svg.addEventListener("tripwire:zoom-in", this.onZoomIn)
    this.svg.addEventListener("tripwire:zoom-out", this.onZoomOut)
    this.svg.addEventListener("tripwire:zoom-reset", this.onZoomReset)
    this.svg.addEventListener("keydown", this.onKeyDown)
    this.svg.addEventListener("dblclick", this.onDblClick)
    window.addEventListener("pointermove", this.onPointerMove, { passive: false })
    window.addEventListener("pointerup", this.onPointerUp)
  },

  updated() {
    this._top = this.topBound()
    const at = this.viewBox()
    const w = VIEW_W / this.zoom
    const h = VIEW_H / this.zoom
    if (at.x !== this.ox || at.y !== this.oy || at.w !== w || at.h !== h) {
      this.setView(this.ox, this.oy, this.zoom)
    }
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onPointerDown)
    this.svg.removeEventListener("click", this.onClick, true)
    this.svg.removeEventListener("wheel", this.onWheel)
    this.svg.removeEventListener("tripwire:zoom-in", this.onZoomIn)
    this.svg.removeEventListener("tripwire:zoom-out", this.onZoomOut)
    this.svg.removeEventListener("tripwire:zoom-reset", this.onZoomReset)
    this.svg.removeEventListener("keydown", this.onKeyDown)
    this.svg.removeEventListener("dblclick", this.onDblClick)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
  },

  viewBox() {
    const parts = (this.svg.getAttribute("viewBox") || "0 0 1000 700").split(/\s+/).map(Number)
    return { x: parts[0] || 0, y: parts[1] || 0, w: parts[2] || VIEW_W, h: parts[3] || VIEW_H }
  },

  setView(x, y, zoom) {
    const z = clampZoom(zoom || this.zoom)
    this.zoom = z
    this.ox = x
    this.oy = y
    this.svg.setAttribute("viewBox", `${x} ${y} ${VIEW_W / z} ${VIEW_H / z}`)
    this.updateZoomLabel()
  },

  zoomBy(factor) {
    const w = VIEW_W / this.zoom
    const h = VIEW_H / this.zoom
    this.zoomAt(this.ox + w / 2, this.oy + h / 2, factor)
  },

  zoomAt(svgX, svgY, factor) {
    const next = clampZoom(this.zoom * factor)
    if (next === this.zoom) return
    const ratio = this.zoom / next
    const nx = svgX - (svgX - this.ox) * ratio
    const ny = svgY - (svgY - this.oy) * ratio
    const clamped = this.clampView(nx, ny)
    this.setView(clamped.x, clamped.y, next)
  },

  updateZoomLabel() {
    const label = document.getElementById("chain-zoom-level")
    if (label) label.textContent = `${Math.round(this.zoom * 100)}%`
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
    if (typeof init === "function") init(this.el)
    this.handleEvent("system-chart-data", (payload) => {
      if (window.TripwireCharts && typeof window.TripwireCharts.updateSystemChart === "function") {
        window.TripwireCharts.updateSystemChart(payload)
      }
    })
  },
}

function parseTransform(transform) {
  const match = /translate\(([-\d.]+),\s*([-\d.]+)\)/.exec(transform || "")
  return match ? [parseFloat(match[1]), parseFloat(match[2])] : [0, 0]
}

export { MapDrag as default, ChartMount }
