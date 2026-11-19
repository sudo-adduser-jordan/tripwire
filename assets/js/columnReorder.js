const DRAG_MIME = "text/plain"
const CLICK_GUARD_MS = 200

const ColumnReorder = {
    mounted() {
        this.dragKey = null
        this.dragged = null
        this.indicator = null
        this.dragEndedAt = 0

        this.onDragStart = (ev) => {
            const th = this.columnHeader(ev.target)
            if (!th) return
            this.dragKey = th.dataset.column
            this.dragged = th
            th.classList.add("column-dragging")
            ev.dataTransfer.effectAllowed = "move"
            ev.dataTransfer.setData(DRAG_MIME, this.dragKey)
        }

        this.onDragOver = (ev) => {
            const th = this.columnHeader(ev.target)
            if (!th || !this.dragKey) return
            ev.preventDefault()
            ev.dataTransfer.dropEffect = "move"
            if (th === this.dragged) {
                this.clearIndicator()
                return
            }
            const rect = th.getBoundingClientRect()
            this.markIndicator(th, ev.clientX > rect.left + rect.width / 2)
        }

        this.onDragLeave = (ev) => {
            const th = this.columnHeader(ev.target)
            if (!th || th !== this.indicator) return
            if (ev.relatedTarget && th.contains(ev.relatedTarget)) return
            this.clearIndicator()
        }

        this.onDrop = (ev) => {
            const th = this.columnHeader(ev.target)
            if (!th || !this.dragKey) return
            ev.preventDefault()

            const keys = this.columnKeys()
            const from = keys.indexOf(this.dragKey)
            const to = keys.indexOf(th.dataset.column)
            const rect = th.getBoundingClientRect()
            const after = ev.clientX > rect.left + rect.width / 2
            const dragged = this.dragKey
            this.clear()

            if (from < 0 || to < 0 || from === to) return

            const next = keys.filter((key) => key !== dragged)
            next.splice(next.indexOf(th.dataset.column) + (after ? 1 : 0), 0, dragged)

            if (next.join(",") === keys.join(",")) return
            this.pushEventTo(this.el, "reorder-columns", { order: next })
        }

        this.onDragEnd = () => {
            this.dragEndedAt = Date.now()
            this.clear()
        }

        this.onClick = (ev) => {
            if (!this.dragEndedAt || Date.now() - this.dragEndedAt > CLICK_GUARD_MS) return
            ev.stopPropagation()
            ev.preventDefault()
        }

        this.el.addEventListener("dragstart", this.onDragStart)
        this.el.addEventListener("dragover", this.onDragOver)
        this.el.addEventListener("dragleave", this.onDragLeave)
        this.el.addEventListener("drop", this.onDrop)
        this.el.addEventListener("dragend", this.onDragEnd)
        this.el.addEventListener("click", this.onClick, true)
    },

    updated() {
        this.clearIndicator()
    },

    destroyed() {
        this.el.removeEventListener("dragstart", this.onDragStart)
        this.el.removeEventListener("dragover", this.onDragOver)
        this.el.removeEventListener("dragleave", this.onDragLeave)
        this.el.removeEventListener("drop", this.onDrop)
        this.el.removeEventListener("dragend", this.onDragEnd)
        this.el.removeEventListener("click", this.onClick, true)
    },

    columnHeader(target) {
        const th = target.closest("th[data-column]")
        return th && this.el.contains(th) ? th : null
    },

    columnKeys() {
        return Array.from(this.el.querySelectorAll("th[data-column]")).map((th) => th.dataset.column)
    },

    markIndicator(th, after) {
        if (this.indicator !== th) this.clearIndicator()
        this.indicator = th
        th.classList.toggle("column-drop-before", !after)
        th.classList.toggle("column-drop-after", after)
    },

    clearIndicator() {
        if (this.indicator) {
            this.indicator.classList.remove("column-drop-before", "column-drop-after")
        }
        this.indicator = null
    },

    clear() {
        this.dragKey = null
        if (this.dragged) this.dragged.classList.remove("column-dragging")
        this.dragged = null
        this.clearIndicator()
    },
}

export default ColumnReorder
