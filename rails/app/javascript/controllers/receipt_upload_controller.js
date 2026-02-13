import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "preview", "status", "result"]

  connect() {
    this.fileTarget.addEventListener("change", () => this.onFileChange())
  }

  async onFileChange() {
    const file = this.fileTarget.files?.[0]
    if (!file) return

    this.showPreview(file)
    await this.upload(file)
  }

  showPreview(file) {
    const url = URL.createObjectURL(file)
    this.previewTarget.src = url
    this.previewTarget.style.display = "block"
  }

  async upload(file) {
    this.setStatus("アップロード中…")
    this.resultTarget.textContent = ""

    const form = new FormData()
    form.append("image", file)

    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const res = await fetch("/receipts", {
      method: "POST",
      headers: csrf ? { "X-CSRF-Token": csrf } : {},
      body: form,
    })

    const json = await res.json().catch(() => null)

    if (!res.ok) {
      const msg = json?.error || `Upload failed (${res.status})`
      this.setStatus(`失敗: ${msg}`)
      this.resultTarget.textContent = JSON.stringify(json, null, 2)
      return
    }

    this.setStatus("完了")
    this.resultTarget.textContent = JSON.stringify(json, null, 2)
  }

  setStatus(text) {
    this.statusTarget.textContent = text
  }
}

