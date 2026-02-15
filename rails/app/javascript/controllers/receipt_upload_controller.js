import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "preview", "status", "result", "submit"]

  connect() {
    this.fileTarget.addEventListener("change", () => this.onFileChange())
    this.resetUi()
  }

  resetUi() {
    this.setStatus("")
    this.resultTarget.textContent = ""
    this.disableSubmit()
  }

  onFileChange() {
    const file = this.fileTarget.files?.[0]
    if (!file) {
      this.resetUi()
      return
    }

    this.showPreview(file)
    this.setStatus("準備OK。アップロード開始を押してください。")
    this.enableSubmit()
  }

  showPreview(file) {
    const url = URL.createObjectURL(file)
    this.previewTarget.src = url
    this.previewTarget.style.display = "block"
  }

  async submit(event) {
    event?.preventDefault?.()

    const file = this.fileTarget.files?.[0]
    if (!file) {
      this.setStatus("画像を選択してください。")
      return
    }

    await this.upload(file)
  }

  async upload(file) {
    this.setStatus("アップロード + 抽出中…（少し時間がかかります）")
    this.resultTarget.textContent = ""
    this.disableSubmit()

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
      this.enableSubmit()
      return
    }

    this.setStatus("完了（抽出結果を表示しました）")
    this.resultTarget.textContent = JSON.stringify(json, null, 2)
    this.enableSubmit()
  }

  setStatus(text) {
    this.statusTarget.textContent = text
  }

  disableSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = true
    this.submitTarget.setAttribute("aria-disabled", "true")
  }

  enableSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = false
    this.submitTarget.setAttribute("aria-disabled", "false")
  }
}

