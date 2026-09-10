import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "status"]

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  async copy() {
    const text = this.sourceTarget.textContent.trim()

    try {
      await navigator.clipboard.writeText(text)
      this.#announce("Copied")
      return
    } catch {
      this.#selectSource()
      this.#announce(document.execCommand("copy") ? "Copied" : "Selected")
    }
  }

  #announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
    if (!this.hasButtonTarget) return

    this.buttonTarget.textContent = message
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.buttonTarget.textContent = "Copy"
      if (this.hasStatusTarget) this.statusTarget.textContent = ""
    }, 2000)
  }

  #selectSource() {
    const selection = window.getSelection()
    const range = document.createRange()
    range.selectNodeContents(this.sourceTarget)
    selection.removeAllRanges()
    selection.addRange(range)
  }
}
