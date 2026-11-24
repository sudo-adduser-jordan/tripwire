import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/tripwire"
import topbar from "../vendor/topbar"
import mapDrag, { ChartMount } from "./mapDrag"
import AutoDismiss from "./autoDismiss"
import LockToggle from "./lockToggle"
import GridWidget from "./gridWidget"
import ScrollIntoView from "./scrollIntoView"
import NotesComposer from "./notesComposer"
import ColumnReorder from "./columnReorder"
import CopyText from "./copyText"
import GlobalPaste from "./globalPaste"
import SearchSuggest from "./searchSuggest"
import CardGrid from "./cardGrid"
import CharacterSwitch from "./characterSwitch"
import ThemeSelect from "./themeSelect"
import SettingsShortcut from "./settingsShortcut"

const GridStack = {
    mounted() {
        this._tries = 0
        this._bindLayoutEvents()
        this._ensure()
    },

    updated() {
        if (window.TripwireGridStack) {
            window.TripwireGridStack.init(this.el)
            window.TripwireGridStack.refresh(this.el)
            this._bindLayoutEvents()
        } else {
            this._ensure()
        }
    },

    _ensure() {
        if (window.TripwireGridStack) {
            window.TripwireGridStack.init(this.el)
            window.TripwireGridStack.refresh(this.el)
            this._bindLayoutEvents()
            return
        }
        if (this._tries < 100) {
            this._tries += 1
            setTimeout(() => this._ensure(), 100)
            return
        }
        this.el.classList.remove('grid-stack-loading')
    },

    _bindLayoutEvents() {
        if (!this._layoutEventsBound) {
            this._layoutEventsBound = true
            this.handleEvent('layout-capture', () => {
                const widgets = window.TripwireGridStack?.snapshot() || {}
                this.pushEvent('layout-captured', { widgets: widgets })
            })
            this.handleEvent('layout-apply', ({ widgets }) => {
                window.TripwireGridStack?.apply(widgets)
            })
        }

        const grid = window.TripwireGrid
        if (!grid || grid._layoutChangeBound) return
        grid._layoutChangeBound = true
        grid.on('change', () => {
            if (this.el._layoutApplying) return
            if (grid.opts && grid.opts.staticGrid) return
            this.pushEvent('layout-changed', {})
        })
    },

    destroyed() {
        window.TripwireGridStack?.destroy()
    },
}

const hooks = {
    ...colocatedHooks,
    AutoDismiss: AutoDismiss,
    MapDrag: mapDrag,
    LockToggle: LockToggle,
    ChartMount: ChartMount,
    GridStack: GridStack,
    GridWidget: GridWidget,
    ScrollIntoView: ScrollIntoView,
    NotesComposer: NotesComposer,
    ColumnReorder: ColumnReorder,
    CopyText: CopyText,
    GlobalPaste: GlobalPaste,
    SearchSuggest: SearchSuggest,
    CardGrid: CardGrid,
    CharacterSwitch: CharacterSwitch,
    ThemeSelect: ThemeSelect,
    SettingsShortcut: SettingsShortcut,
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks,
})

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket

const focusPrimaryAction = () => {
    const target = document.querySelector("[data-autofocus]")
    if (target && !target.disabled) target.focus()
}

if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", focusPrimaryAction)
} else {
    focusPrimaryAction()
}

if (process.env.NODE_ENV === "development") {
    window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
        reloader.enableServerLogs()

        let keyDown
        window.addEventListener("keydown", e => keyDown = e.key)
        window.addEventListener("keyup", _e => keyDown = null)
        window.addEventListener("click", e => {
            if (keyDown === "c") {
                e.preventDefault()
                e.stopImmediatePropagation()
                reloader.openEditorAtCaller(e.target)
            } else if (keyDown === "d") {
                e.preventDefault()
                e.stopImmediatePropagation()
                reloader.openEditorAtDef(e.target)
            }
        }, true)

        window.liveReloader = reloader
    })
}
