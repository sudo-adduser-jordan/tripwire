const csrfToken = () =>
  document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

const storeSession = (path) =>
  fetch(path, {
    method: "POST",
    credentials: "same-origin",
    headers: { "x-csrf-token": csrfToken() },
  })

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
    await storeSession(`/auth/session/${eve_id}`)
    if (mask_id) await this._storeMask(mask_id)
  },

  _storeMask(mask_id) {
    return storeSession(`/auth/session/mask/${mask_id}`)
  },
}

export default CharacterSwitch
