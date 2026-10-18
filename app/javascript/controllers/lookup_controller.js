import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]
  static values = { url: String }

  connect() {
    this.index = -1
    this.abortController = null
  }

  disconnect() {
    this.#cancel()
    clearTimeout(this.timer)
  }

  query() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#fetch(), 200)
  }

  keydown(event) {
    if (this.listTarget.hidden) return

    const options = this.#options()
    if (!options.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.index = (this.index + 1) % options.length
      this.#highlight()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.index = (this.index - 1 + options.length) % options.length
      this.#highlight()
    } else if (event.key === "Enter" && this.index >= 0) {
      event.preventDefault()
      options[this.index].querySelector("a")?.click()
    } else if (event.key === "Escape") {
      this.hide()
    }
  }

  hide(event) {
    if (event?.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.listTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.index = -1
  }

  async #fetch() {
    const q = this.inputTarget.value.trim()
    if (q.length < 1) {
      this.hide()
      this.listTarget.innerHTML = ""
      return
    }

    this.#cancel()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", q)

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        signal: this.abortController.signal
      })
      if (!response.ok) return
      this.listTarget.innerHTML = await response.text()
      if (this.#options().length) {
        this.listTarget.hidden = false
        this.inputTarget.setAttribute("aria-expanded", "true")
      } else {
        this.hide()
      }
      this.index = -1
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  #options() {
    return Array.from(this.listTarget.querySelectorAll('[role="option"]'))
  }

  #highlight() {
    this.#options().forEach((option, i) => {
      option.setAttribute("aria-selected", i === this.index ? "true" : "false")
      option.classList.toggle("bg-line", i === this.index)
    })
    this.#options()[this.index]?.scrollIntoView({ block: "nearest" })
  }

  #cancel() {
    this.abortController?.abort()
    this.abortController = null
  }
}
