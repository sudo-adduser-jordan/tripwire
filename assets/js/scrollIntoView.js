const ScrollIntoView = {
  mounted() {
    const bar = document.querySelector("nav.sticky")
    const offset = (bar ? bar.getBoundingClientRect().height : 0) + 16
    const top = this.el.getBoundingClientRect().top + window.scrollY - offset
    window.scrollTo({ top, behavior: "smooth" })
  },
}

export default ScrollIntoView
