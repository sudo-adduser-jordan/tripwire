const GridWidget = {
    mounted() {
        this._tries = 0
        this._register()
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

    updated() {
        const container = this.el.closest ? this.el.closest('.grid-stack') : null
        if (container && window.TripwireGridStack) window.TripwireGridStack.refresh(container)
    },

    destroyed() {
        const grid = window.TripwireGrid
        if (grid && this.el.gridstackNode) grid.removeWidget(this.el, false)
    },
}

export default GridWidget
