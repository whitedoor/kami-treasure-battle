import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file", "fileName", "preview", "status", "result", "permalink", "submit", "rawPanel", "raw"]

  connect() {
    this.fileTargets.forEach((input) => input.addEventListener("change", () => this.onFileChange(input)))
    this.cacheUiElements()
    this.resetUi()
  }

  cacheUiElements() {
    // "写真の選択"エリア（撮影する/画像を選ぶ/錬成開始）をまとめて制御したい
    this._selectionActionsEl = this.element.querySelector('.ktb-actions[aria-label="写真の選択"]') || null
    // ファイル入力のラベル（2つ）を取得
    this._pickerLabels = this.fileTargets.map((input) => input.closest("label")).filter(Boolean)
  }

  resetUi() {
    this._receiptUploadId = null
    this.setStatus("")
    this.resultTarget.innerHTML = ""
    if (this.hasPermalinkTarget) this.permalinkTarget.innerHTML = ""
    if (this.hasFileNameTarget) this.fileNameTarget.textContent = ""
    if (this.hasRawPanelTarget) this.rawPanelTarget.style.display = "none"
    if (this.hasRawTarget) this.rawTarget.textContent = ""
    this.hidePreview()
    this.hideSubmit()
    this.disableSubmit()
    this.showSelectionActions()
    this.showPickers()
    this.setSubmitLabelExtract()
  }

  onFileChange(changedInput) {
    // Keep track of the last interacted input (camera/picker).
    // NOTE: Clearing the other input programmatically can trigger extra change events
    // on some browsers, which may re-disable the button. So we avoid clearing.
    this._selectedInput = changedInput

    const file = changedInput?.files?.[0] || this.selectedFile()
    if (!file) {
      this.resetUi()
      return
    }

    this._receiptUploadId = null
    this.showPreview(file)
    if (this.hasFileNameTarget) this.fileNameTarget.textContent = `選択中: ${file.name}`
    this.setStatus("準備OK。エネルギー抽出が完了すると自動で次の画面へ移動します。")
    this.setSubmitLabelExtract()
    this.showSubmit()
    this.enableSubmit()

    // 画像選択後は「錬成開始」だけ見せたい
    this.showSelectionActions()
    this.hidePickers()
  }

  showPreview(file) {
    if (this._previewUrl) URL.revokeObjectURL(this._previewUrl)
    const url = URL.createObjectURL(file)
    this._previewUrl = url
    this.previewTarget.src = url
    this.previewTarget.style.display = "block"
  }

  hidePreview() {
    if (!this.hasPreviewTarget) return
    if (this._previewUrl) URL.revokeObjectURL(this._previewUrl)
    this._previewUrl = null
    this.previewTarget.removeAttribute("src")
    this.previewTarget.style.display = "none"
  }

  hideSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.style.display = "none"
  }

  showSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.style.display = "inline-block"
  }

  selectedFile() {
    const preferred = this._selectedInput?.files?.[0]
    if (preferred) return preferred
    for (const input of this.fileTargets) {
      const file = input.files?.[0]
      if (file) return file
    }
    return null
  }

  async submit(event) {
    event?.preventDefault?.()

    const file = this.selectedFile()
    if (!file) {
      this.setStatus("画像を選択してください。")
      return
    }

    await this.upload(file)
  }

  primaryAction(event) {
    // エネルギー抽出完了後は、同じ位置のボタンで「カードを錬成する（次へ）」へ遷移する
    if (this._receiptUploadId) {
      event?.preventDefault?.()
      window.location.href = `/receipt_uploads/${this._receiptUploadId}`
      return
    }
    this.submit(event)
  }

  async upload(file) {
    this.setStatus("エネルギー抽出中…（完了すると自動で次の画面へ移動します）")
    this.resultTarget.innerHTML = ""
    this._receiptUploadId = null
    this.setSubmitLabelExtract()
    this.disableSubmit()
    if (this.hasPermalinkTarget) this.permalinkTarget.innerHTML = ""
    if (this.hasRawPanelTarget) this.rawPanelTarget.style.display = "none"
    if (this.hasRawTarget) this.rawTarget.textContent = ""

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
      if (this.hasRawPanelTarget) this.rawPanelTarget.style.display = "block"
      if (this.hasRawTarget) this.rawTarget.textContent = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2)
      this.enableSubmit()
      // 失敗時は再選択できるように戻す
      this.showSelectionActions()
      this.showPickers()
      this.setSubmitLabelExtract()
      return
    }

    this.setStatus("エネルギー抽出完了！このままカード錬成を開始します…（自動で移動します）")
    if (payload?.receipt_upload_id) {
      this._receiptUploadId = payload.receipt_upload_id
      if (this.hasPermalinkTarget) this.permalinkTarget.innerHTML = ""
      this.setSubmitLabelForge()
      // 抽出ボタンの位置に「カードを錬成する」ボタンだけ残す
      this.showSelectionActions()
      this.hidePickers()
      this.showSubmit()
    }

    if (this.hasRawPanelTarget) this.rawPanelTarget.style.display = "block"
    if (this.hasRawTarget) this.rawTarget.textContent = JSON.stringify(payload, null, 2)
    this.enableSubmit()

    // 抽出完了後に自動でカード錬成を開始する
    if (this._receiptUploadId) {
      await this.forgeCardAndRedirect(this._receiptUploadId)
    }
  }

  async forgeCardAndRedirect(receiptUploadId) {
    this.setStatus("カード錬成中…（完了すると自動でカード画面へ移動します）")
    this.disableSubmit()

    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const res = await fetch(`/receipt_uploads/${receiptUploadId}/generate_card`, {
      method: "POST",
      headers: {
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
        Accept: "application/json",
      },
      credentials: "same-origin",
    })

    const payload = await res.json().catch(() => null)
    if (!res.ok) {
      const msg = payload?.error || `錬成に失敗しました (${res.status})`
      this.setStatus(`失敗: ${msg}`)
      this.enableSubmit()
      return
    }

    const to = payload?.redirect_to || `/receipt_uploads/${receiptUploadId}`
    window.location.href = to
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

  hideSelectionActions() {
    if (!this._selectionActionsEl) return
    this._selectionActionsEl.style.display = "none"
  }

  showSelectionActions() {
    if (!this._selectionActionsEl) return
    this._selectionActionsEl.style.display = ""
  }

  hidePickers() {
    if (!this._pickerLabels?.length) return
    this._pickerLabels.forEach((label) => {
      label.style.display = "none"
      label.setAttribute("aria-hidden", "true")
    })
  }

  showPickers() {
    if (!this._pickerLabels?.length) return
    this._pickerLabels.forEach((label) => {
      label.style.display = ""
      label.removeAttribute("aria-hidden")
    })
  }

  setSubmitLabelExtract() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.textContent = "エネルギー抽出"
  }

  setSubmitLabelForge() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.textContent = "カードを錬成する"
  }
}

