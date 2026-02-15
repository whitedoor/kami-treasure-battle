import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    cardId: Number,
    status: String,
    generateUrl: String,
    pollUrl: String,
  }

  static targets = ["statusText", "errorText", "image", "skeleton"]

  connect() {
    // Start automatically only when pending (avoid infinite retries on failure).
    if (this.statusValue === "generated") {
      this.showImageHideSkeleton()
      return
    }
    if (this.statusValue === "failed") {
      this.showImageHideSkeleton()
      return
    }

    if (this.statusValue === "generating") {
      this.showSkeletonHideImage()
      this.pollUntilDone()
      return
    }

    if (this.statusValue !== "pending") return

    const key = `ktb_artwork_started_${this.cardIdValue}`
    if (window.sessionStorage?.getItem(key)) return
    window.sessionStorage?.setItem(key, "1")

    this.start()
  }

  async start() {
    this.setStatusUi("生成中…")
    this.clearErrorUi()
    this.showSkeletonHideImage()

    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const res = await fetch(this.generateUrlValue, {
      method: "POST",
      headers: {
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
        Accept: "application/json",
      },
      credentials: "same-origin",
    })

    const payload = await res.json().catch(() => null)
    if (!res.ok) {
      const msg = payload?.error || `画像生成の開始に失敗しました (${res.status})`
      this.setStatusUi("失敗")
      this.setErrorUi(msg)
      return
    }

    this.pollUntilDone()
  }

  pollUntilDone() {
    let tries = 0
    const maxTries = 90 // ~3min (2s interval)

    const tick = async () => {
      tries += 1
      if (tries > maxTries) {
        this.setStatusUi("時間超過")
        this.setErrorUi("画像生成に時間がかかっています。しばらく待ってから再読み込みしてください。")
        // Show placeholder image so the page doesn't look stuck forever.
        this.showImageHideSkeleton()
        return
      }

      const res = await fetch(this.pollUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })
      const payload = await res.json().catch(() => null)
      const status = payload?.card?.artwork_status
      const err = payload?.card?.artwork_error

      if (!status) return
      this.setStatusUi(status === "generated" ? "生成済み" : status === "generating" ? "生成中…" : status)
      if (err) this.setErrorUi(err)

      if (status === "generated") {
        this.clearErrorUi()
        this.showImageHideSkeleton()
        this.refreshImage()
        return
      }

      if (status === "failed") {
        this.showImageHideSkeleton()
        return
      }

      window.setTimeout(tick, 2000)
    }

    window.setTimeout(tick, 1200)
  }

  refreshImage() {
    if (!this.hasImageTarget) return
    const src = this.imageTarget.getAttribute("src") || ""
    const sep = src.includes("?") ? "&" : "?"
    this.imageTarget.setAttribute("src", `${src}${sep}ts=${Date.now()}`)
  }

  showSkeletonHideImage() {
    if (this.hasSkeletonTarget) this.skeletonTarget.style.display = ""
    if (this.hasImageTarget) this.imageTarget.style.display = "none"
  }

  showImageHideSkeleton() {
    if (this.hasSkeletonTarget) this.skeletonTarget.style.display = "none"
    if (this.hasImageTarget) this.imageTarget.style.display = ""
  }

  setStatusUi(text) {
    if (!this.hasStatusTextTarget) return
    this.statusTextTarget.textContent = text
  }

  setErrorUi(text) {
    if (!this.hasErrorTextTarget) return
    this.errorTextTarget.textContent = text
    this.errorTextTarget.style.display = ""
  }

  clearErrorUi() {
    if (!this.hasErrorTextTarget) return
    this.errorTextTarget.textContent = ""
    this.errorTextTarget.style.display = "none"
  }
}

