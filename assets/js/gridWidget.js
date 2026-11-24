const FOCUSABLE = 'button, a[href], input, select, textarea, summary, [contenteditable="true"], [tabindex]:not([tabindex="-1"])'

const GridWidget = {
    mounted() {
        this._tries = 0
        this._onPointerDown = (ev) => {
            if (ev.button) return
            const target = ev.target
            const keep = target && target.closest ? target.closest(FOCUSABLE) : null
            if (keep && keep !== this.el) return
            if (typeof this.el.focus === 'function') this.el.focus({ preventScroll: true })
        }
        this.el.addEventListener('pointerdown', this._onPointerDown)
        this._register()
        this._focusInitial()
    },

    _register() {
        const container = this.el.closest ? this.el.closest('.grid-stack') : null
        const grid = (container && container.gridstack) || window.TripwireGrid
        if (!grid) {
            if (this._tries < 20) {
                this._tries += 1
                requestAnimationFrame(() => this._register())
            }
            return
        }
        if (this.el.gridstackNode) return

        grid.makeWidget(this.el)

        if (container && window.TripwireGridStack) window.TripwireGridStack.refresh(container)
    },

    _focusInitial() {
        if (this.el.id !== 'map' || typeof this.el.focus !== 'function') return
        this.el.focus({ preventScroll: true })
    },

    updated() {
        const container = this.el.closest ? this.el.closest('.grid-stack') : null
        if (container && window.TripwireGridStack) window.TripwireGridStack.refresh(container)
    },

    destroyed() {
        if (this._onPointerDown) this.el.removeEventListener('pointerdown', this._onPointerDown)
        const grid = window.TripwireGrid
        if (grid && this.el.gridstackNode) grid.removeWidget(this.el, false)
    },
}

export default GridWidget
