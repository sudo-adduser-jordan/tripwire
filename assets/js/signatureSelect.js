const EDITABLE = "input, textarea, select, [contenteditable='true']"

const SignatureSelect = {
    mounted() {
        this.onKeyDown = (event) => {
            const root = this.el.closest(".grid-stack-item")
            if (!root || !event.target || !root.contains(event.target)) return
            if (event.target.closest && event.target.closest(EDITABLE)) return

            if ((event.ctrlKey || event.metaKey) && event.key && event.key.toLowerCase() === "a") {
                event.preventDefault()
                this.pushEventTo(this.el, "select-all", {})
                return
            }

            if ((event.ctrlKey || event.metaKey) && event.key && event.key.toLowerCase() === "c") {
                if (window.getSelection && window.getSelection().toString() !== "") return
                event.preventDefault()
                this.pushEventTo(this.el, "copy-selected", {})
                return
            }

            if (!event.ctrlKey && !event.metaKey && (event.key === "Delete" || event.key === "Backspace")) {
                event.preventDefault()
                this.pushEventTo(this.el, "delete-selected", {})
            }
        }

        document.addEventListener("keydown", this.onKeyDown)
    },

    handleEvent(event) {
        if (event && event.type === "clipboard-write" && event.text) {
            const text = event.text
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).catch(() => this.fallbackCopy(text))
            } else {
                this.fallbackCopy(text)
            }
        }
    },

    fallbackCopy(text) {
        const area = document.createElement("textarea")
        area.value = text
        area.setAttribute("readonly", "")
        area.style.position = "fixed"
        area.style.opacity = "0"
        document.body.appendChild(area)
        area.select()
        document.execCommand("copy")
        document.body.removeChild(area)
    },

    destroyed() {
        document.removeEventListener("keydown", this.onKeyDown)
    },
}

export default SignatureSelect
