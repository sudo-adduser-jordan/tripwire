import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

// Lock state is owned by LiveView (`data-grid-locked` on the grid element,
// toggled via the `toggle-grid-lock` event). This module only applies it.

function gridLocked(el) {
    return !el || el.dataset.gridLocked !== 'false'
}

function syncLock(el) {
    const grid = window.TripwireGrid
    if (!grid || typeof grid.setStatic !== 'function') return
    grid.setStatic(gridLocked(el))
    const lockSvg = document.getElementById('lock-svg')
    if (lockSvg) lockSvg.style.fill = gridLocked(el) ? '#ff6700' : '#605dff'
}

// Reveal the grid on first layout so pre-init paint never shows a pile-up.
// The loading class lives in the server template, so morphdom re-adds it
// on every LiveView patch; only animate the very first reveal, later ones
// just unhide so selecting systems never flashes the grid.
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

function initGrid(el) {
    if (!el) return null
    // Already initialized (e.g. hook remounted): still ensure visibility.
    if (el.gridstack) {
        syncLock(el)
        reveal(el)
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

    window.TripwireGrid = grid
    syncLock(el)
    reveal(el)

    return grid
}

function destroyGrid() {
    if (window.TripwireGrid) {
        window.TripwireGrid.destroy(false)
        window.TripwireGrid = null
    }
}

function itemSignature(el) {
    return Array.from(el.querySelectorAll(':scope > .grid-stack-item'))
        .map((n) => n.id + '|' + n.getAttribute('gs-x') + ',' + n.getAttribute('gs-y') + ',' + n.getAttribute('gs-w') + ',' + n.getAttribute('gs-h'))
        .join(';');
}

// Content-only patch (selection, signatures, notes): re-assert node
// attributes morphdom may have wiped, without re-laying out the engine.
function touchGrid(el) {
    const grid = el && el.gridstack
    if (!grid || !grid.engine) return

    grid.engine.nodes.forEach((node) => {
        if (!node || !node.el || node._moving || node._resizing) return
        if (typeof grid._writeAttr === 'function') {
            grid._writeAttr(node.el, node)
        }
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

// LiveView re-renders the dashboard subtree on every patch (selection,
// signatures, notes) and morphdom drops attributes it did not render
// (gridstack's CSS vars and item inline styles), so re-apply the grid
// state after each update. Full engine refresh is only needed when the
// widget set itself changed (e.g. settings toggled); content-only patches
// get a light touch so the whole grid doesn't visibly re-layout/flash.
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
        reconcile(el, grid)
        if (typeof grid.compact === 'function') grid.compact()
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

    // Container margins are runtime inline styles, so a morph wipes them.
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
        if (!node || !node.el || node._moving || node._resizing) return
        node.el.classList.add('grid-stack-item')
        if (typeof grid._writeAttr === 'function') {
            grid._writeAttr(node.el, node)
        }
    })

    if (typeof grid._updateContainerHeight === 'function') grid._updateContainerHeight()
    syncLock(el)
    reveal(el)
}

// The dashboard grid is owned by LiveView, so it is initialized from the
// GridStack hook once the view has mounted instead of at script load.
window.TripwireGridStack = { init: initGrid, refresh: refreshGrid, destroy: destroyGrid }
