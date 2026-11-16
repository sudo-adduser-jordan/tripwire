const ScrollIntoView = {
  mounted() {
    this.el.scrollIntoView({ behavior: "smooth", block: "start" })
  },
}

export default ScrollIntoView
