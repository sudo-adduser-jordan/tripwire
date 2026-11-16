const CopyText = {
    mounted() {
        this._onClick = () => {
            const text = this.el.dataset.copy
            if (!text) return
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).catch(() => {})
            } else {
                const ta = document.createElement('textarea')
                ta.value = text
                document.body.appendChild(ta)
                ta.select()
                try {
                    document.execCommand('copy')
                } catch (_) {
                    // clipboard unavailable; no-op
                }
                ta.remove()
            }
        }
        this.el.addEventListener('click', this._onClick)
    },

    destroyed() {
        if (this._onClick) this.el.removeEventListener('click', this._onClick)
    },
}

export default CopyText
