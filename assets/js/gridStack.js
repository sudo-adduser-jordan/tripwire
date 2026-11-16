import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

// Locked by default; module scope so the choice survives grid re-init.
let isLocked = true
let lockHandlerAttached = false

// Toggle the dashboard layout lock. Delegated on `document` so it survives
// LiveView re-renders of the nav button.
function ensureLockHandler() {
    if (lockHandlerAttached) return
    lockHandlerAttached = true

    document.addEventListener('click', (e) => {
        const button = e.target && e.target.closest ? e.target.closest('#lock-button') : null
        if (!button) return
        const grid = window.TripwireGrid
        if (!grid) return
        isLocked = !isLocked
        grid.setStatic(isLocked)
        const lockSvg = document.getElementById('lock-svg')
        if (lockSvg) lockSvg.style.fill = isLocked ? "#605dff" : "#ff6700"
    })
}

// Reveal the grid on first layout so pre-init paint never shows a pile-up.
function reveal(el) {
    if (!el || !el.classList.contains('grid-stack-loading')) return
    el.classList.remove('grid-stack-loading')
    const reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (!reduceMotion && typeof el.animate === 'function') {
        el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 150, easing: 'ease-out' })
    }
}

function initGrid(el) {
    if (!el) return null
    // Already initialized (e.g. hook remounted): still ensure visibility.
    if (el.gridstack) {
        reveal(el)
        return el.gridstack
    }

    const grid = GridStack.init({
        cellHeight: 80,
        columnOpts: {
            breakpointForWindow: true,
            breakpoints: [{ w: 700, c: 1 }, { w: 850, c: 2 }, { w: 950, c: 2 }, { w: 1100, c: 2 }]
        },
        staticGrid: isLocked,
    }, el)

    window.TripwireGrid = grid
    ensureLockHandler()
    reveal(el)

    return grid
}

function destroyGrid() {
    if (window.TripwireGrid) {
        window.TripwireGrid.destroy(false)
        window.TripwireGrid = null
    }
}

// LiveView re-renders the dashboard subtree and drops attributes it did not
// render (gridstack's CSS vars and item inline styles), so re-apply the grid
// state after each update. Skips nodes mid-drag/resize so a patch never
// yanks a widget out from under the pointer.
function refreshGrid(el) {
    const grid = el && el.gridstack
    if (!grid || !grid.engine) return

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
    reveal(el)
}

// The dashboard grid is owned by LiveView, so it is initialized from the
// GridStack hook once the view has mounted instead of at script load.
window.TripwireGridStack = { init: initGrid, refresh: refreshGrid, destroy: destroyGrid }
