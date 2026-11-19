// Registers a conditionally rendered widget with GridStack so it packs and
// drags alongside the server-rendered dashboard widgets. Position comes from
// the element's own gs-* attributes; retries until the grid exists so bundle
// load order can never strand the widget in the corner.
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

        // No options: makeWidget() reads x/y/w/h from the gs-* attributes.
        grid.makeWidget(this.el)

        if (container && window.TripwireGridStack) window.TripwireGridStack.refresh(container)
    },

    // An event this widget handled itself patches only this subtree, so the
    // grid container hook never runs and the item loses the styles gridstack
    // wrote onto it. Re-assert them before the browser paints the collapse.
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
