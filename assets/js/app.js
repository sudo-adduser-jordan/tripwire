import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/tripwire"
import topbar from "../vendor/topbar"
import mapDrag, { ChartMount } from "./mapDrag"
import LockToggle from "./lockToggle"
import GridWidget from "./gridWidget"
import ScrollIntoView from "./scrollIntoView"
import CopyText from "./copyText"
import GlobalPaste from "./globalPaste"

const GridStack = {
    mounted() {
        this._tries = 0
        this._ensure()
    },

    updated() {
        if (window.TripwireGridStack) {
            window.TripwireGridStack.init(this.el)
            window.TripwireGridStack.refresh(this.el)
        } else {
            this._ensure()
        }
    },

    // dashboard.js (gridstack lib) is 3MB+ and may still be downloading when
    // LiveView mounts. Retry instead of leaving the grid hidden forever.
    _ensure() {
        if (window.TripwireGridStack) {
            window.TripwireGridStack.init(this.el)
            window.TripwireGridStack.refresh(this.el)
            return
        }
        if (this._tries < 100) {
            this._tries += 1
            setTimeout(() => this._ensure(), 100)
            return
        }
        // Last resort: never leave the dashboard invisible.
        this.el.classList.remove('grid-stack-loading')
    },

    destroyed() {
        window.TripwireGridStack?.destroy()
    },
}

const hooks = {
    ...colocatedHooks,
    MapDrag: mapDrag,
    LockToggle: LockToggle,
    ChartMount: ChartMount,
    GridStack: GridStack,
    GridWidget: GridWidget,
    ScrollIntoView: ScrollIntoView,
    CopyText: CopyText,
    GlobalPaste: GlobalPaste,
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket
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
