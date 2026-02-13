require "google/cloud/storage"
require "securerandom"

class GcsUploader
  class Error < StandardError; end

  # uploaded_file: ActionDispatch::Http::UploadedFile
  def self.upload_receipt!(uploaded_file:, env_prefix: Rails.env)
    raise Error, "uploaded_file is required" if uploaded_file.nil?

    bucket_name = ENV["GCS_BUCKET"]
    raise Error, "ENV['GCS_BUCKET'] is not set" if bucket_name.blank?

    storage = build_storage
    bucket = storage.bucket(bucket_name)
    raise Error, "GCS bucket not found: #{bucket_name.inspect}" if bucket.nil?

    ext = guess_extension(uploaded_file.content_type) || File.extname(uploaded_file.original_filename).delete_prefix(".")
    ext = "jpg" if ext.blank?

    object_key = [
      env_prefix,
      "receipts",
      Time.now.utc.strftime("%Y/%m/%d"),
      "#{SecureRandom.uuid}.#{ext}"
    ].join("/")

    file = bucket.create_file(
      uploaded_file.tempfile.path,
      object_key,
      content_type: uploaded_file.content_type.presence || "application/octet-stream"
    )

    {
      bucket: bucket_name,
      object_key: object_key,
      gcs_uri: "gs://#{bucket_name}/#{object_key}",
      generation: file.generation
    }
  end

  def self.build_storage
    project_id = ENV["GCP_PROJECT_ID"].presence
    credentials = ENV["GOOGLE_APPLICATION_CREDENTIALS"].presence

    if credentials
      Google::Cloud::Storage.new(project_id: project_id, credentials: credentials)
    else
      # Falls back to ADC (e.g. `gcloud auth application-default login`)
      Google::Cloud::Storage.new(project_id: project_id)
    end
  end
  private_class_method :build_storage

  def self.guess_extension(content_type)
    case content_type
    when "image/jpeg" then "jpg"
    when "image/png" then "png"
    when "image/webp" then "webp"
    else
      nil
    end
  end
  private_class_method :guess_extension
end

