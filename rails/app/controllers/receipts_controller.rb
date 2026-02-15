class ReceiptsController < ApplicationController
  protect_from_forgery with: :exception

  def new
  end

  def create
    uploaded = params[:image]

    unless uploaded.respond_to?(:tempfile)
      render json: { ok: false, error: "image is required" }, status: :bad_request
      return
    end

    result = GcsUploader.upload_receipt!(uploaded_file: uploaded, env_prefix: Rails.env)

    extraction = GeminiReceiptExtractor.extract!(
      image_path: uploaded.tempfile.path,
      mime_type: uploaded.content_type.presence || "application/octet-stream"
    )

    render json: { ok: true, receipt: result, extraction: extraction }, status: :created
  rescue GcsUploader::Error => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  rescue GeminiReceiptExtractor::Error => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  rescue LoadError => e
    render json: { ok: false, error: "server is missing gems (run bundle install). #{e.message}" }, status: :service_unavailable
  end
end

