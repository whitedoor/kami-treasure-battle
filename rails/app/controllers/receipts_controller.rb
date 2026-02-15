class ReceiptsController < ApplicationController
  protect_from_forgery with: :exception

  def new
  end

  def create
    uploaded = params[:image]
    receipt_upload = nil

    unless uploaded.respond_to?(:tempfile)
      render json: { ok: false, error: "image is required" }, status: :bad_request
      return
    end

    result = GcsUploader.upload_receipt!(uploaded_file: uploaded, env_prefix: Rails.env)

    receipt_upload = ReceiptUpload.create!(
      status: "uploaded",
      gcs_bucket: result.fetch(:bucket),
      gcs_object_key: result.fetch(:object_key),
      gcs_uri: result.fetch(:gcs_uri),
      gcs_generation: result[:generation]
    )

    extraction =
      GeminiReceiptExtractor.extract!(
        image_path: uploaded.tempfile.path,
        mime_type: uploaded.content_type.presence || "application/octet-stream"
      )

    receipt_upload.update!(
      status: "extracted",
      extracted_json: extraction[:extracted] || {},
      raw_text: extraction[:raw_text],
      model: extraction[:model],
      auth_mode: extraction[:auth_mode],
      location: extraction[:location],
      usage_json: extraction[:usage] || {}
    )

    render json: { ok: true, receipt_upload_id: receipt_upload.id, receipt: result, extraction: extraction }, status: :created
  rescue GcsUploader::Error => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  rescue GeminiReceiptExtractor::Error => e
    receipt_upload&.update(status: "failed", error_message: e.message)
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    receipt_upload&.update(status: "failed", error_message: e.message)
    render json: { ok: false, error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique => e
    receipt_upload&.update(status: "failed", error_message: e.message)
    render json: { ok: false, error: "DB constraint error: #{e.message}" }, status: :unprocessable_entity
  rescue LoadError => e
    render json: { ok: false, error: "server is missing gems (run bundle install). #{e.message}" }, status: :service_unavailable
  end
end

