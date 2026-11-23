const CharacterSwitch = {
  mounted() {
    this.handleEvent("character-switched", ({ eve_id, mask_id }) => {
      this._switchCharacter(eve_id, mask_id)
    })

    this.handleEvent("mask-switched", ({ mask_id }) => {
      this._storeMask(mask_id)
    })
  },

  async _switchCharacter(eve_id, mask_id) {
    await fetch(`/auth/session/${eve_id}`, { credentials: "same-origin" })
    if (mask_id) await this._storeMask(mask_id)
  },

  _storeMask(mask_id) {
    return fetch(`/auth/session/mask/${mask_id}`, { credentials: "same-origin" })
  },
}

export default CharacterSwitch
