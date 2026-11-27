const EDITABLE = "input, textarea, select, [contenteditable='true']"

const SignatureSelect = {
    mounted() {
        this.onKeyDown = (event) => {
            if (!(event.ctrlKey || event.metaKey)) return
            if (!event.key || event.key.toLowerCase() !== "a") return

            const root = this.el.closest(".grid-stack-item")
            if (!root || !event.target || !root.contains(event.target)) return
            if (event.target.closest && event.target.closest(EDITABLE)) return

            event.preventDefault()
            this.pushEventTo(this.el, "select-all", {})
        }

        document.addEventListener("keydown", this.onKeyDown)
    },

    destroyed() {
        document.removeEventListener("keydown", this.onKeyDown)
    },
}

export default SignatureSelect
