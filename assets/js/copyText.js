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
                }
                ta.remove()
            }
            this._flashCopied()
        }
        this.el.addEventListener('click', this._onClick)
    },

    updated() {
        if (this._resetTimer) {
            clearTimeout(this._resetTimer)
            this._resetTimer = null
        }
    },

    destroyed() {
        if (this._onClick) this.el.removeEventListener('click', this._onClick)
        if (this._resetTimer) clearTimeout(this._resetTimer)
    },

    _flashCopied() {
        const copyIcon = this.el.querySelector('.copy-icon')
        const copiedIcon = this.el.querySelector('.copied-icon')
        if (!copyIcon || !copiedIcon) return
        if (this._resetTimer) clearTimeout(this._resetTimer)
        copyIcon.classList.add('hidden')
        copiedIcon.classList.remove('hidden')
        if (copiedIcon.animate) {
            copiedIcon.animate(
                [{ transform: 'scale(0.5)' }, { transform: 'scale(1.25)' }, { transform: 'scale(1)' }],
                { duration: 250, easing: 'ease-out' }
            )
        }
        this._resetTimer = setTimeout(() => {
            copiedIcon.classList.add('hidden')
            copyIcon.classList.remove('hidden')
            this._resetTimer = null
        }, 1200)
    },
}

export default CopyText
