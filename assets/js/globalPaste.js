const GlobalPaste = {
    mounted() {
        this._onPaste = (e) => {
            const target = e.target
            if (target && target.closest &&
                target.closest('input, textarea, select, [contenteditable="true"]')) return
            const text = e.clipboardData && e.clipboardData.getData
                ? e.clipboardData.getData('text')
                : ''
            if (!text || !text.trim()) return
            this.pushEvent('global-paste', { text })
        }
        window.addEventListener('paste', this._onPaste)
    },

    destroyed() {
        if (this._onPaste) window.removeEventListener('paste', this._onPaste)
    },
}

export default GlobalPaste
