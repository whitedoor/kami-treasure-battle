import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "preview", "status", "result", "permalink", "submit"]

  connect() {
    this.fileTarget.addEventListener("change", () => this.onFileChange())
    this.resetUi()
  }

  resetUi() {
    this.setStatus("")
    this.resultTarget.textContent = ""
    if (this.hasPermalinkTarget) this.permalinkTarget.innerHTML = ""
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
    if (this.hasPermalinkTarget) this.permalinkTarget.innerHTML = ""

    const form = new FormData()
    form.append("image", file)

    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const res = await fetch("/receipts", {
      method: "POST",
      headers: csrf ? { "X-CSRF-Token": csrf } : {},
      body: form,
      credentials: "same-origin",
    })

    const contentType = res.headers.get("content-type") || ""
    const isJson = contentType.includes("application/json")
    const payload = isJson ? await res.json().catch(() => null) : await res.text().catch(() => "")

    if (!res.ok) {
      const msg =
        payload?.error ||
        (typeof payload === "string" && payload.trim() ? payload.slice(0, 300) : null) ||
        `Upload failed (${res.status})`
      this.setStatus(`失敗: ${msg}`)
      this.resultTarget.textContent = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2)
      this.enableSubmit()
      return
    }

    this.setStatus("完了（抽出結果を表示しました）")
    this.resultTarget.textContent = JSON.stringify(payload, null, 2)
    if (this.hasPermalinkTarget && payload?.receipt_upload_id) {
      const id = payload.receipt_upload_id
      this.permalinkTarget.innerHTML = `<a href="/receipt_uploads/${id}">保存結果を見る（ReceiptUpload #${id}）</a>`
    }
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

