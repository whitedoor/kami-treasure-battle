require "base64"
require "json"
require "net/http"
require "uri"

class VertexImagenGenerator
  class Error < StandardError; end

  DEFAULT_MODEL = "imagen-3.0-generate-002".freeze
  DEFAULT_VERTEX_LOCATION = "us-central1".freeze
  DEFAULT_OPEN_TIMEOUT_SECONDS = 10
  DEFAULT_READ_TIMEOUT_SECONDS = 90

  # Returns: { model:, location:, prompt:, bytes:, mime_type: }
  def self.generate!(prompt:, mime_type: "image/png", seed: nil)
    begin
      require "googleauth"
    rescue LoadError => e
      raise Error, "googleauth gem is missing. #{e.message}"
    end

    project_id = ENV["GCP_PROJECT_ID"].presence || ENV["GOOGLE_CLOUD_PROJECT"].presence
    raise Error, "ENV['GCP_PROJECT_ID'] is not set" if project_id.blank?

    location = ENV.fetch("CARD_IMAGE_VERTEX_LOCATION", DEFAULT_VERTEX_LOCATION).to_s
    raise Error, "ENV['CARD_IMAGE_VERTEX_LOCATION'] is blank" if location.strip.empty?

    model = ENV.fetch("CARD_IMAGE_MODEL", DEFAULT_MODEL).to_s
    raise Error, "ENV['CARD_IMAGE_MODEL'] is blank" if model.strip.empty?

    uri = URI.parse("https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:predict")

    parameters = {
      sampleCount: 1,
      aspectRatio: "1:1",
      language: "ja",
      personGeneration: "dont_allow",
      safetySetting: "block_medium_and_above",
      outputOptions: { mimeType: mime_type },
      # allow deterministic seed: watermark must be false
      addWatermark: false
    }
    parameters[:seed] = Integer(seed) if seed.present?

    payload = {
      instances: [
        { prompt: prompt }
      ],
      parameters: parameters
    }

    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    credentials = Google::Auth.get_application_default(scopes)
    token_hash = credentials.fetch_access_token!
    access_token = token_hash["access_token"].to_s
    raise Error, "failed to fetch access token" if access_token.empty?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = env_int("CARD_IMAGE_OPEN_TIMEOUT_SECONDS", DEFAULT_OPEN_TIMEOUT_SECONDS)
    http.read_timeout = env_int("CARD_IMAGE_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT_SECONDS)

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json; charset=utf-8"
    req["Authorization"] = "Bearer #{access_token}"
    req.body = JSON.generate(payload)

    res = http.request(req)
    body = res.body.to_s
    json = JSON.parse(body) rescue nil

    unless res.is_a?(Net::HTTPSuccess)
      message =
        json&.dig("error", "message") ||
        json&.dig("error") ||
        "Vertex Imagen request failed (status=#{res.code})"
      raise Error, message
    end

    prediction = json&.dig("predictions", 0) || {}
    b64 = prediction["bytesBase64Encoded"].to_s
    out_mime = prediction["mimeType"].to_s.presence || mime_type
    raise Error, "Imagen response did not contain image bytes" if b64.empty?

    {
      model: model,
      location: location,
      prompt: prediction["prompt"].presence || prompt,
      bytes: Base64.decode64(b64),
      mime_type: out_mime
    }
  end

  def self.env_int(name, default_value)
    raw = ENV[name].to_s.strip
    return Integer(default_value) if raw.empty?
    Integer(raw)
  rescue ArgumentError, TypeError
    Integer(default_value)
  end
  private_class_method :env_int
end

