const DRAG_THRESHOLD = 4
const VIEW_W = 1000
const VIEW_H = 700
const PAD = 40
const NODE_W = 140
const NODE_H = 88
const MIN_ZOOM = 0.25
const MAX_ZOOM = 4
const ZOOM_STEP = 1.25
const DEFAULT_ZOOM = 1 / ZOOM_STEP

function clampZoom(z) {
    return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, z))
}

function clampValue(value, low, high) {
    return Math.min(high, Math.max(low, value))
}

function clampAxis(value, min, max, size, align) {
    const low = min - PAD
    const high = max + PAD - size
    if (low <= high) return clampValue(value, low, high)
    return align === "start" ? low : (min + max - size) / 2
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
    this._bounds = null
    this._raf = 0
    this._pending = null
    this.zoom = DEFAULT_ZOOM
    const at = this.viewBox()
    this.ox = at.x
    this.oy = at.y
    if (at.w) this.zoom = clampZoom(VIEW_W / at.w)
    this._bounds = this.bounds()
    this.setView(this.ox, this.oy, this.zoom)

    this._guideResize = new ResizeObserver(() => this.syncGuides())
    this._guideResize.observe(this.svg)

    this.onPointerDown = (ev) => {
      if (this.isLocked()) return
      if (ev.target.closest("g[data-system-id]")) return
      const ctm = this.svg.getScreenCTM()
      if (!ctm || !ctm.a || !ctm.d) return
      this.panning = true
      this.suppressed = false
      this.startClient = { x: ev.clientX, y: ev.clientY }
      this.scale = { x: ctm.a, y: ctm.d }
      this.origin = { x: this.ox, y: this.oy }
      this._bounds = this.bounds()
      ev.preventDefault()
    }

    this.onPointerMove = (ev) => {
      if (!this.panning || !this.startClient) return
      const dx = (ev.clientX - this.startClient.x) / this.scale.x
      const dy = (ev.clientY - this.startClient.y) / this.scale.y
      if (!this.suppressed && Math.hypot(dx, dy) > DRAG_THRESHOLD) this.suppressed = true
      this._pending = { x: this.origin.x - dx, y: this.origin.y - dy }
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

    this.onZoomIn = () => {
      if (this.isLocked()) return
      this.zoomBy(ZOOM_STEP)
    }
    this.onZoomOut = () => {
      if (this.isLocked()) return
      this.zoomBy(1 / ZOOM_STEP)
    }
    this.onZoomReset = () => {
      if (this.isLocked()) return
      this.zoomTo(DEFAULT_ZOOM)
    }

    this.onKeyDown = (ev) => {
      if (this.isLocked()) return
      if (ev.key === "+" || ev.key === "=") {
        ev.preventDefault()
        this.zoomBy(ZOOM_STEP)
      } else if (ev.key === "-" || ev.key === "_") {
        ev.preventDefault()
        this.zoomBy(1 / ZOOM_STEP)
      } else if (ev.key === "0") {
        ev.preventDefault()
        this.zoomTo(DEFAULT_ZOOM)
      }
    }

    this.onDblClick = (ev) => {
      if (this.isLocked()) return
      ev.preventDefault()
      const rect = this.svg.getBoundingClientRect()
      const w = VIEW_W / this.zoom
      const h = VIEW_H / this.zoom
      const fx = rect.width ? (ev.clientX - rect.left) / rect.width : 0.5
      const fy = rect.height ? (ev.clientY - rect.top) / rect.height : 0.5
      this.zoomAt(this.ox + fx * w, this.oy + fy * h, ev.shiftKey ? 1 / ZOOM_STEP : ZOOM_STEP)
    }

    this.handleEvent("reset-pan", ({ x, y, zoom }) => {
      if (this.isLocked()) return
      this._bounds = this.bounds()
      this.setView(x, y, zoom || DEFAULT_ZOOM)
    })

    this.handleEvent("map-zoom", ({ zoom }) => {
      if (this.isLocked()) return
      this.zoomTo((zoom || 1) * DEFAULT_ZOOM)
      this.anchorTop()
    })

    this.svg.addEventListener("pointerdown", this.onPointerDown)
    this.svg.addEventListener("click", this.onClick, true)
    this.svg.addEventListener("tripwire:zoom-in", this.onZoomIn)
    this.svg.addEventListener("tripwire:zoom-out", this.onZoomOut)
    this.svg.addEventListener("tripwire:zoom-reset", this.onZoomReset)
    this.svg.addEventListener("keydown", this.onKeyDown)
    this.svg.addEventListener("dblclick", this.onDblClick)
    window.addEventListener("pointermove", this.onPointerMove, { passive: false })
    window.addEventListener("pointerup", this.onPointerUp)
  },

  updated() {
    this._bounds = this.bounds()
    this.setView(this.ox, this.oy, this.zoom)
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
    if (this._guideResize) this._guideResize.disconnect()
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onPointerDown)
    this.svg.removeEventListener("click", this.onClick, true)
    this.svg.removeEventListener("tripwire:zoom-in", this.onZoomIn)
    this.svg.removeEventListener("tripwire:zoom-out", this.onZoomOut)
    this.svg.removeEventListener("tripwire:zoom-reset", this.onZoomReset)
    this.svg.removeEventListener("keydown", this.onKeyDown)
    this.svg.removeEventListener("dblclick", this.onDblClick)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
  },

  viewBox() {
    const fallback = `0 0 ${VIEW_W / DEFAULT_ZOOM} ${VIEW_H / DEFAULT_ZOOM}`
    const parts = (this.svg.getAttribute("viewBox") || fallback).split(/\s+/).map(Number)
    return {
      x: parts[0] || 0,
      y: parts[1] || 0,
      w: parts[2] || VIEW_W / DEFAULT_ZOOM,
      h: parts[3] || VIEW_H / DEFAULT_ZOOM,
    }
  },

  isLocked() {
    return this.el && this.el.dataset && this.el.dataset.locked === "true"
  },

  setView(x, y, zoom) {
    const z = clampZoom(zoom || this.zoom)
    const next = this.clampView(x, y, z)
    this.zoom = z
    this.ox = next.x
    this.oy = next.y
    this.svg.setAttribute("viewBox", `${next.x} ${next.y} ${VIEW_W / z} ${VIEW_H / z}`)
    this.updateZoomLabel()
    this.syncGuides()
  },

  syncGuides() {
    if (!this.svg) return
    const ctm = this.svg.getScreenCTM()
    if (!ctm || !ctm.d) return
    const view = this.viewBox()
    const guides = document.getElementById("map-row-guides")
    const height = this.svg.getBoundingClientRect().height
    if (guides && height) guides.setAttribute("viewBox", `0 ${view.y} ${view.w} ${height / ctm.d}`)
    const container = this.svg.parentElement
    if (!container) return
    container.querySelectorAll("[data-guide-y]").forEach((label) => {
      const y = Number.parseFloat(label.dataset.guideY)
      if (Number.isFinite(y)) label.style.top = `${(y - view.y) * ctm.d}px`
    })
  },

  zoomBy(factor) {
    const w = VIEW_W / this.zoom
    const h = VIEW_H / this.zoom
    this.zoomAt(this.ox + w / 2, this.oy + h / 2, factor)
  },

  anchorTop() {
    this._bounds = this.bounds()
    if (!this._bounds) return
    this.setView(this.ox, this._bounds.minY - PAD, this.zoom)
  },

  zoomTo(zoom) {
    const target = clampZoom(zoom)
    if (target === this.zoom) return
    this.zoomBy(target / this.zoom)
  },

  zoomAt(svgX, svgY, factor) {
    const next = clampZoom(this.zoom * factor)
    if (next === this.zoom) return
    const ratio = this.zoom / next
    const nx = svgX - (svgX - this.ox) * ratio
    const ny = svgY - (svgY - this.oy) * ratio
    this.setView(nx, ny, next)
  },

  updateZoomLabel() {
    const label = document.getElementById("chain-zoom-level")
    if (label) label.textContent = `${Math.round((this.zoom / DEFAULT_ZOOM) * 100)}%`
  },

  clampView(x, y, zoom) {
    const bounds = this._bounds
    if (!bounds) return { x, y }
    const z = zoom || this.zoom
    return {
      x: clampAxis(x, bounds.minX, bounds.maxX, VIEW_W / z, "center"),
      y: clampAxis(y, bounds.minY, bounds.maxY, VIEW_H / z, "start"),
    }
  },

  nodeSize() {
    const w = Number.parseFloat(this.svg.dataset.nodeW)
    const h = Number.parseFloat(this.svg.dataset.nodeH)
    return {
      w: Number.isFinite(w) ? w : NODE_W,
      h: Number.isFinite(h) ? h : NODE_H,
    }
  },

  bounds() {
    const nodes = this.svg.querySelectorAll("g[data-system-id]")
    if (!nodes.length) return null
    const { w, h } = this.nodeSize()
    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity
    nodes.forEach((node) => {
      const [x, y] = parseTransform(node.getAttribute("transform"))
      if (x < minX) minX = x
      if (y < minY) minY = y
      if (x + w > maxX) maxX = x + w
      if (y + h > maxY) maxY = y + h
    })
    return { minX, minY, maxX, maxY }
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
