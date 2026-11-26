import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

function gridLocked(el) {
    return !el || el.dataset.gridLocked !== 'false'
}

function syncLock(el) {
    const grid = window.ZtripwireGrid
    if (!grid || typeof grid.setStatic !== 'function') return
    grid.setStatic(gridLocked(el))
    const lockSvg = document.getElementById('lock-svg')
    if (lockSvg) lockSvg.style.fill = gridLocked(el) ? '#ff6700' : '#605dff'
}

function reveal(el) {
    if (!el || !el.classList.contains('grid-stack-loading')) return
    el.classList.remove('grid-stack-loading')
    if (el._revealed) return
    el._revealed = true
    const reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (!reduceMotion && typeof el.animate === 'function') {
        el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 150, easing: 'ease-out' })
    }
}

function fitMap(el, grid) {
    const mapEl = el && el.querySelector('#map')
    if (!mapEl || !grid || !grid.engine || !mapEl.gridstackNode) return

    const cellHeight = parseFloat((grid.opts && grid.opts.cellHeight) || '') || 80
    const rows = Math.max(6, Math.round(window.innerHeight / cellHeight) - 1)

    if (mapEl.gridstackNode.h === rows) return
    grid.update(mapEl, { h: rows })
}

function watchViewport(el, grid) {
    if (!el || el._mapResize) return

    el._mapResize = () => {
        if (el._mapResizeFrame) return
        el._mapResizeFrame = window.requestAnimationFrame(() => {
            el._mapResizeFrame = 0
            fitMap(el, grid)
        })
    }

    window.addEventListener('resize', el._mapResize)
}

function unwatchViewport(el) {
    if (!el || !el._mapResize) return
    window.removeEventListener('resize', el._mapResize)
    if (el._mapResizeFrame) window.cancelAnimationFrame(el._mapResizeFrame)
    el._mapResize = null
    el._mapResizeFrame = 0
}

function initGrid(el) {
    if (!el) return null
    if (el.gridstack) {
        syncLock(el)
        reveal(el)
        watchViewport(el, el.gridstack)
        fitMap(el, el.gridstack)
        return el.gridstack
    }

    const grid = GridStack.init({
        cellHeight: 80,
        columnOpts: {
            breakpointForWindow: true,
            breakpoints: [{ w: 700, c: 1 }, { w: 850, c: 2 }, { w: 950, c: 2 }, { w: 1100, c: 2 }]
        },
        staticGrid: gridLocked(el),
    }, el)

    window.ZtripwireGrid = grid
    syncLock(el)
    reveal(el)
    watchViewport(el, grid)
    fitMap(el, grid)

    return grid
}

function destroyGrid() {
    if (window.ZtripwireGrid) {
        unwatchViewport(window.ZtripwireGrid.el)
        window.ZtripwireGrid.destroy(false)
        window.ZtripwireGrid = null
    }
}

function itemSignature(el) {
    return Array.from(el.querySelectorAll(':scope > .grid-stack-item'))
        .map((n) => {
            const node = n.gridstackNode
            const read = (attr, key) =>
                node && node[key] !== undefined && node[key] !== null ? String(node[key]) : n.getAttribute(attr)
            return n.id + '|' + read('gs-x', 'x') + ',' + read('gs-y', 'y') + ',' + read('gs-w', 'w') + ',' + read('gs-h', 'h')
        })
        .join(';');
}

function restoreHandles(el) {
    const resizable = el.ddElement && el.ddElement.ddResizable
    if (!resizable || !resizable.handlers) return

    resizable.handlers.forEach((handle) => {
        if (handle.el && handle.el.parentElement !== el) el.appendChild(handle.el)
    })

    if (resizable.option && resizable.option.autoHide) {
        el.classList.add('ui-resizable-autohide')
    }
}

function restoreItem(grid, node) {
    if (!node || !node.el) return
    const el = node.el

    el.classList.add('grid-stack-item')
    if (typeof grid._writeAttr === 'function') grid._writeAttr(el, node)
    restoreHandles(el)

    if (typeof grid.prepareDragDrop !== 'function') return

    if ((grid.opts && grid.opts.staticGrid) || !node._initDD) {
        grid.prepareDragDrop(el)
    }
}

function touchGrid(el) {
    const grid = el && el.gridstack
    if (!grid || !grid.engine) return

    grid.engine.nodes.forEach((node) => {
        if (!node || node._moving || node._resizing) return
        restoreItem(grid, node)
    })

    if (typeof grid._updateContainerHeight === 'function') grid._updateContainerHeight()
    syncLock(el)
}

function reconcile(el, grid) {
    const nodes = (grid.engine && grid.engine.nodes) || []

    nodes.slice().forEach((node) => {
        if (!node || !node.el) return
        if (!el.contains(node.el)) grid.removeWidget(node.el, false)
    })

    Array.from(el.children).forEach((child) => {
        if (!child.classList || !child.classList.contains('grid-stack-item')) return
        if (child.gridstackNode) return
        grid.makeWidget(child)
    })
}

function refreshGrid(el) {
    const grid = el && el.gridstack
    if (!grid || !grid.engine) return

    const sig = itemSignature(el)
    if (el._gridSig === sig) {
        touchGrid(el)
        return
    }
    const widgetSetChanged = el._gridSig !== undefined
    el._gridSig = sig

    if (widgetSetChanged) {
        suppressLayoutChange(el)
        reconcile(el, grid)
        repack(grid)
    }

    if (typeof grid._updateColumnVar === 'function') {
        grid._updateColumnVar()
    } else {
        el.classList.add('gs-' + grid.getColumn())
        el.style.setProperty('--gs-column-width', `${100 / grid.getColumn()}%`)
    }

    if (grid.opts && grid.opts.cellHeight) {
        el.style.setProperty('--gs-cell-height', `${grid.opts.cellHeight}${grid.opts.cellHeightUnit || 'px'}`)
    }

    const marginUnit = (grid.opts && grid.opts.marginUnit) || 'px'
    const margin = (grid.opts && grid.opts.margin !== undefined) ? grid.opts.margin : 10
    const pick = (v) => (v === undefined || v === null || v === '') ? margin : v
    el.style.setProperty('--gs-item-margin-top', `${pick(grid.opts && grid.opts.marginTop)}${marginUnit}`)
    el.style.setProperty('--gs-item-margin-right', `${pick(grid.opts && grid.opts.marginRight)}${marginUnit}`)
    el.style.setProperty('--gs-item-margin-bottom', `${pick(grid.opts && grid.opts.marginBottom)}${marginUnit}`)
    el.style.setProperty('--gs-item-margin-left', `${pick(grid.opts && grid.opts.marginLeft)}${marginUnit}`)

    if (typeof grid._setStaticClass === 'function') {
        grid._setStaticClass()
    } else {
        el.classList.toggle('grid-stack-static', !!grid.opts.staticGrid)
    }
    if (!grid.opts || grid.opts.animate !== false) el.classList.add('grid-stack-animate')

    grid.engine.nodes.forEach((node) => {
        if (!node || node._moving || node._resizing) return
        restoreItem(grid, node)
    })

    if (typeof grid._updateContainerHeight === 'function') grid._updateContainerHeight()
    syncLock(el)
    reveal(el)
    watchViewport(el, grid)
    fitMap(el, grid)
}

const WIDGET_IDS = {
    'system-container': 'system',
    notes: 'notes',
    signatures: 'signatures',
    map: 'map',
}

function repack(grid) {
    const engine = grid && grid.engine
    if (engine && typeof engine._packNodes === 'function') {
        engine._packNodes()
        return
    }
    if (grid && typeof grid.compact === 'function') grid.compact()
}

function suppressLayoutChange(el) {
    if (!el) return
    el._layoutApplying = true
    window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
            el._layoutApplying = false
        })
    })
}

function widgetElementId(key) {
    return Object.keys(WIDGET_IDS).find((id) => WIDGET_IDS[id] === key)
}

function snapshotWidgets() {
    const grid = window.ZtripwireGrid
    if (!grid || !grid.engine) return {}

    const widgets = {}
    ;(grid.engine.nodes || []).forEach((node) => {
        const key = node && node.el ? WIDGET_IDS[node.el.id] : null
        if (!key) return
        widgets[key] = { x: node.x, y: node.y, w: node.w }
        if (key !== 'map') widgets[key].h = node.h
    })
    return widgets
}

function applyLayout(widgets) {
    const grid = window.ZtripwireGrid
    if (!grid || !grid.engine || !widgets) return

    suppressLayoutChange(grid.el)

    Object.entries(widgets).forEach(([key, position]) => {
        const id = widgetElementId(key)
        const el = id ? document.getElementById(id) : null
        if (!el || !el.gridstackNode) return

        const target = { x: position.x, y: position.y, w: position.w }
        if (key !== 'map' && position.h) target.h = position.h
        grid.update(el, target)
    })

    grid.el._gridSig = itemSignature(grid.el)
}

window.ZtripwireGridStack = {
    init: initGrid,
    refresh: refreshGrid,
    destroy: destroyGrid,
    snapshot: snapshotWidgets,
    apply: applyLayout,
}
