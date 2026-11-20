const CharacterSwitch = {
  mounted() {
    this.handleEvent("character-switched", ({ eve_id }) => {
      fetch(`/auth/session/${eve_id}`, { credentials: "same-origin" })
    })
  },
}

export default CharacterSwitch
