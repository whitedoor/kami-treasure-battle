import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    outcome: String,
    playerDamage: Number,
    cpuDamage: Number,
    ended: Boolean,
    winner: String
  }

  static targets = ["playerSide", "cpuSide", "banner", "endBanner"]

  connect() {
    this.playTurnEffect()
    this.playEndEffect()
  }

  playTurnEffect() {
    const outcome = (this.hasOutcomeValue ? this.outcomeValue : "").toString()
    if (!outcome) return

    const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
    const playerDamage = Number(this.hasPlayerDamageValue ? this.playerDamageValue : 0)
    const cpuDamage = Number(this.hasCpuDamageValue ? this.cpuDamageValue : 0)

    if (outcome === "player") {
      this.element.classList.add("ktb-battle--win")
      this.showBanner("WIN!", "win", reduceMotion)
      if (cpuDamage > 0) this.hit(this.cpuSideTarget, reduceMotion)
      this.buff(this.playerSideTarget, reduceMotion)
      return
    }

    if (outcome === "cpu") {
      this.element.classList.add("ktb-battle--lose")
      this.showBanner("LOSE...", "lose", reduceMotion)
      if (playerDamage > 0) this.hit(this.playerSideTarget, reduceMotion)
      this.buff(this.cpuSideTarget, reduceMotion)
      return
    }

    if (outcome === "tie") {
      this.element.classList.add("ktb-battle--tie")
      this.showBanner("TIE", "tie", reduceMotion)
      if (playerDamage > 0) this.hit(this.playerSideTarget, reduceMotion)
      if (cpuDamage > 0) this.hit(this.cpuSideTarget, reduceMotion)
    }
  }

  playEndEffect() {
    const ended = this.hasEndedValue ? !!this.endedValue : false
    if (!ended) return

    const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
    const winner = (this.hasWinnerValue ? this.winnerValue : "").toString()

    // Small delay so the turn effect reads first
    window.setTimeout(() => {
      if (winner === "player") {
        this.element.classList.add("ktb-battle--end-win")
        this.showEndBanner("勝利！", "win", reduceMotion)
        if (!reduceMotion) this.confetti()
        return
      }

      if (winner === "cpu") {
        this.element.classList.add("ktb-battle--end-lose")
        this.showEndBanner("敗北…", "lose", reduceMotion)
        return
      }

      // draw / unknown
      this.element.classList.add("ktb-battle--end-draw")
      this.showEndBanner("引き分け", "tie", reduceMotion)
    }, 220)
  }

  showBanner(text, variant, reduceMotion) {
    if (!this.hasBannerTarget) return
    this.bannerTarget.textContent = text
    this.bannerTarget.classList.remove("ktb-battleBanner--win", "ktb-battleBanner--lose", "ktb-battleBanner--tie")
    this.bannerTarget.classList.add(`ktb-battleBanner--${variant}`, "is-show")

    if (reduceMotion) return
    window.setTimeout(() => {
      this.bannerTarget?.classList?.remove("is-show")
    }, 900)
  }

  showEndBanner(text, variant, reduceMotion) {
    if (!this.hasEndBannerTarget) return
    this.endBannerTarget.textContent = text
    this.endBannerTarget.classList.remove("ktb-battleEndBanner--win", "ktb-battleEndBanner--lose", "ktb-battleEndBanner--tie")
    this.endBannerTarget.classList.add(`ktb-battleEndBanner--${variant}`, "is-show")

    if (reduceMotion) return
    window.setTimeout(() => {
      this.endBannerTarget?.classList?.remove("is-show")
    }, 1600)
  }

  hit(el, reduceMotion) {
    if (!el) return
    el.classList.remove("ktb-battle__side--hit", "ktb-battle__side--shake")
    // force reflow so the animation re-triggers even on back/forward or rapid reloads
    // eslint-disable-next-line no-unused-expressions
    el.offsetHeight
    el.classList.add("ktb-battle__side--hit")
    if (!reduceMotion) el.classList.add("ktb-battle__side--shake")

    if (reduceMotion) return
    window.setTimeout(() => {
      el?.classList?.remove("ktb-battle__side--hit", "ktb-battle__side--shake")
    }, 650)
  }

  buff(el, reduceMotion) {
    if (!el) return
    el.classList.remove("ktb-battle__side--buff")
    // eslint-disable-next-line no-unused-expressions
    el.offsetHeight
    el.classList.add("ktb-battle__side--buff")

    if (reduceMotion) return
    window.setTimeout(() => {
      el?.classList?.remove("ktb-battle__side--buff")
    }, 900)
  }

  confetti() {
    const wrap = document.createElement("div")
    wrap.className = "ktb-confetti"
    wrap.setAttribute("aria-hidden", "true")

    const pieces = 26
    for (let i = 0; i < pieces; i++) {
      const p = document.createElement("span")
      p.className = "ktb-confettiPiece"
      const x = Math.random() * 100
      const delay = Math.random() * 0.25
      const dur = 1.4 + Math.random() * 0.9
      const hue = 35 + Math.random() * 45 // gold-ish
      const rot = (Math.random() * 720 - 360).toFixed(0)
      p.style.setProperty("--x", `${x}%`)
      p.style.setProperty("--delay", `${delay}s`)
      p.style.setProperty("--dur", `${dur}s`)
      p.style.setProperty("--hue", `${hue}`)
      p.style.setProperty("--rot", `${rot}deg`)
      wrap.appendChild(p)
    }

    this.element.appendChild(wrap)
    window.setTimeout(() => wrap.remove(), 2600)
  }
}

