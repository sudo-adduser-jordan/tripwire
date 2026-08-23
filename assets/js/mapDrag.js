const MapDrag = {
  mounted() {
    this.svg = this.el
    if (!this.svg) return
    this.selected = null
    this.offset = { x: 0, y: 0 }

    this.onPointerDown = (ev) => {
      const node = ev.target.closest("g[data-system-id]")
      if (!node) return
      this.selected = node
      const pt = this.toSvgPoint(ev)
      if (!pt) return
      const [x, y] = parseTransform(node.getAttribute("transform"))
      this.offset = { x: pt.x - x, y: pt.y - y }
      ev.preventDefault()
    }

    this.onPointerMove = (ev) => {
      if (!this.selected) return
      const pt = this.toSvgPoint(ev)
      if (!pt) return
      const x = Math.max(0, Math.min(pt.x - this.offset.x, 920))
      const y = Math.max(0, Math.min(pt.y - this.offset.y, 650))
      this.selected.setAttribute("transform", `translate(${x}, ${y})`)
      ev.preventDefault()
    }

    this.onPointerUp = (_ev) => {
      if (!this.selected) return
      const [x, y] = parseTransform(this.selected.getAttribute("transform"))
      const id = this.selected.dataset.systemId
      this.selected = null
      this.pushEvent("move-system", { id, x: Math.round(x), y: Math.round(y) })
    }

    this.svg.addEventListener("pointerdown", this.onPointerDown)
    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
  },

  destroyed() {
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onPointerDown)
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
