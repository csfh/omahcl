import { Controller } from "@hotwired/stimulus"

// Tilts the card toward the pointer and moves the foil and glare with it.
// Writes CSS custom properties through the CSSOM, which the CSP allows;
// a style attribute in markup would be blocked.
export default class extends Controller {
  static targets = ["card"]

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.move = this.move.bind(this)
    this.reset = this.reset.bind(this)
    this.element.addEventListener("pointermove", this.move)
    this.element.addEventListener("pointerleave", this.reset)
    this.element.addEventListener("pointercancel", this.reset)
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
    this.element.removeEventListener("pointermove", this.move)
    this.element.removeEventListener("pointerleave", this.reset)
    this.element.removeEventListener("pointercancel", this.reset)
  }

  move(event) {
    if (this.reduced.matches) return

    const { clientX, clientY } = event
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => {
      const box = this.cardTarget.getBoundingClientRect()
      const x = Math.min(Math.max((clientX - box.left) / box.width, 0), 1)
      const y = Math.min(Math.max((clientY - box.top) / box.height, 0), 1)
      this.#set(x, y, true)
    })
  }

  reset() {
    cancelAnimationFrame(this.frame)
    this.#set(0.5, 0.5, false)
  }

  #set(x, y, active) {
    const style = this.cardTarget.style
    style.setProperty("--mx", `${(x * 100).toFixed(1)}%`)
    style.setProperty("--my", `${(y * 100).toFixed(1)}%`)
    style.setProperty("--tilt-x", `${((0.5 - y) * 22).toFixed(2)}deg`)
    style.setProperty("--tilt-y", `${((x - 0.5) * 26).toFixed(2)}deg`)
    style.setProperty("--active", active ? "1" : "0")
  }
}
