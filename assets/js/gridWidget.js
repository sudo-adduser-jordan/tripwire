// Registers a conditionally rendered widget with GridStack so it packs and
// drags alongside the server-rendered dashboard widgets.
const GridWidget = {
    mounted() {
        const grid = window.TripwireGrid
        if (!grid) return

        grid.makeWidget(this.el, {
            w: 12,
            h: 9,
            x: 0,
            y: 0,
        })
    },

    destroyed() {
        const grid = window.TripwireGrid
        if (grid && this.el.gridstackNode) grid.removeWidget(this.el, false)
    },
}

export default GridWidget
