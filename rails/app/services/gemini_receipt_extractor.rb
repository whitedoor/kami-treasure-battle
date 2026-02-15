require "base64"
require "json"
require "net/http"
require "uri"

class GeminiReceiptExtractor
  class Error < StandardError; end

  # Vertex AI publisher model IDs are versioned (e.g. gemini-2.0-flash-001).
  DEFAULT_MODEL = "gemini-2.0-flash-001".freeze
  # Note: Vertex AI のGeminiはリージョン依存。Cloud Runのリージョンと一致する必要はありません。
  # asia-northeast1 で未提供/未アクセスのケースがあるため、デフォルトは提供範囲が広い us-central1 に寄せる。
  DEFAULT_VERTEX_LOCATION = "us-central1".freeze
  DEFAULT_OPEN_TIMEOUT_SECONDS = 10
  DEFAULT_READ_TIMEOUT_SECONDS = 60

  # image_path: String (path to local file)
  # mime_type: String (e.g. "image/jpeg")
  def self.extract!(image_path:, mime_type:)
    auth_mode = ENV.fetch("GEMINI_AUTH_MODE", "api_key").to_s
    case auth_mode
    when "vertex"
      extract_via_vertex!(image_path: image_path, mime_type: mime_type)
    when "api_key"
      extract_via_api_key!(image_path: image_path, mime_type: mime_type)
    else
      raise Error, "ENV['GEMINI_AUTH_MODE'] must be 'api_key' or 'vertex'"
    end
  end

  def self.extract_via_api_key!(image_path:, mime_type:)
    api_key = ENV["GEMINI_API_KEY"].to_s
    raise Error, "ENV['GEMINI_API_KEY'] is not set" if api_key.empty?

    model = ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL).to_s
    raise Error, "ENV['GEMINI_MODEL'] is blank" if model.strip.empty?

    image_bytes = File.binread(image_path)
    image_b64 = Base64.strict_encode64(image_bytes)

    uri = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    uri.query = URI.encode_www_form(key: api_key)

    prompt = <<~PROMPT
      あなたはレシート画像から情報を抽出して、必ずJSONだけを返す抽出器です。
      次のJSONスキーマに厳密に従ってください。余計な文章やコードフェンスは絶対に出力しないでください。

      {
        "items": [{"name": "string", "price_yen": number|null}],
        "card": {"name": "string", "hand": "gu"|"choki"|"pa", "flavor": "string"},
        "notes": "string"
      }

      ルール:
      - items はレシート内の商品行をできるだけ抽出する（商品名と金額）。
      - price_yen は日本円の整数に正規化する（不明なら null）。
      - card.name は「魔法名っぽい」創作カード名。商品名をそのまま使わない（items[*].name と一致/ほぼ一致は不可）。
      - card.name は items[*].name に含まれる文字（ひらがな/カタカナ/漢字/英数字）を一切含めてはいけない（1文字でも一致したらNG）。必ず別の語彙で命名する。
      - card.name は短く力強い日本語（目安: 6〜18文字）。記号や型番/バーコード/品番、店舗名は入れない。
      - 画像が読めず items が弱くても card.name は必ず空にしない（例: 「黄昏の領収符」「白銀の買い物術」などの創作名でOK）。
      - card.hand は商品名からそれっぽく "gu"/"choki"/"pa" を選ぶ。
      - notes には抽出の不確実性や補足を短く書く。
    PROMPT

    payload = {
      contents: [
        {
          role: "user",
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mime_type, data: image_b64 } }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json"
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = env_int("GEMINI_OPEN_TIMEOUT_SECONDS", DEFAULT_OPEN_TIMEOUT_SECONDS)
    http.read_timeout = env_int("GEMINI_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT_SECONDS)

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json; charset=utf-8"
    req.body = JSON.generate(payload)

    res = http.request(req)
    body = res.body.to_s
    json = JSON.parse(body) rescue nil

    unless res.is_a?(Net::HTTPSuccess)
      message =
        json&.dig("error", "message") ||
        json&.dig("error") ||
        "Gemini API request failed (status=#{res.code})"
      raise Error, message
    end

    text = json.dig("candidates", 0, "content", "parts", 0, "text").to_s
    extracted = parse_jsonish(text)

    {
      model: model,
      auth_mode: "api_key",
      extracted: extracted,
      raw_text: text,
      usage: json["usageMetadata"]
    }
  end
  private_class_method :extract_via_api_key!

  def self.extract_via_vertex!(image_path:, mime_type:)
    begin
      require "googleauth"
    rescue LoadError => e
      raise Error, "googleauth gem is missing. #{e.message}"
    end

    project_id = ENV["GCP_PROJECT_ID"].presence || ENV["GOOGLE_CLOUD_PROJECT"].presence
    raise Error, "ENV['GCP_PROJECT_ID'] is not set" if project_id.blank?

    location = ENV.fetch("GEMINI_VERTEX_LOCATION", DEFAULT_VERTEX_LOCATION).to_s
    raise Error, "ENV['GEMINI_VERTEX_LOCATION'] is blank" if location.strip.empty?

    model = ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL).to_s
    raise Error, "ENV['GEMINI_MODEL'] is blank" if model.strip.empty?

    image_bytes = File.binread(image_path)
    image_b64 = Base64.strict_encode64(image_bytes)

    uri = URI.parse("https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:generateContent")

    prompt = <<~PROMPT
      あなたはレシート画像から情報を抽出して、必ずJSONだけを返す抽出器です。
      次のJSONスキーマに厳密に従ってください。余計な文章やコードフェンスは絶対に出力しないでください。

      {
        "items": [{"name": "string", "price_yen": number|null}],
        "card": {"name": "string", "hand": "gu"|"choki"|"pa", "flavor": "string"},
        "notes": "string"
      }

      ルール:
      - items はレシート内の商品行をできるだけ抽出する（商品名と金額）。
      - price_yen は日本円の整数に正規化する（不明なら null）。
      - card.name は「魔法名っぽい」創作カード名。商品名をそのまま使わない（items[*].name と一致/ほぼ一致は不可）。
      - card.name は items[*].name に含まれる文字（ひらがな/カタカナ/漢字/英数字）を一切含めてはいけない（1文字でも一致したらNG）。必ず別の語彙で命名する。
      - card.name は短く力強い日本語（目安: 6〜18文字）。記号や型番/バーコード/品番、店舗名は入れない。
      - 画像が読めず items が弱くても card.name は必ず空にしない（例: 「黄昏の領収符」「白銀の買い物術」などの創作名でOK）。
      - card.hand は商品名からそれっぽく "gu"/"choki"/"pa" を選ぶ。
      - notes には抽出の不確実性や補足を短く書く。
    PROMPT

    payload = {
      contents: [
        {
          role: "user",
          parts: [
            { text: prompt },
            { inlineData: { mimeType: mime_type, data: image_b64 } }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json"
      }
    }

    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    credentials = Google::Auth.get_application_default(scopes)
    token_hash = credentials.fetch_access_token!
    access_token = token_hash["access_token"].to_s
    raise Error, "failed to fetch access token" if access_token.empty?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = env_int("GEMINI_OPEN_TIMEOUT_SECONDS", DEFAULT_OPEN_TIMEOUT_SECONDS)
    http.read_timeout = env_int("GEMINI_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT_SECONDS)

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
        "Vertex AI request failed (status=#{res.code})"
      raise Error, message
    end

    text = json.dig("candidates", 0, "content", "parts", 0, "text").to_s
    extracted = parse_jsonish(text)

    {
      model: model,
      auth_mode: "vertex",
      location: location,
      extracted: extracted,
      raw_text: text,
      usage: json["usageMetadata"]
    }
  end
  private_class_method :extract_via_vertex!

  def self.env_int(name, default_value)
    raw = ENV[name].to_s.strip
    return Integer(default_value) if raw.empty?
    Integer(raw)
  rescue ArgumentError, TypeError
    Integer(default_value)
  end
  private_class_method :env_int

  def self.parse_jsonish(text)
    return {} if text.strip.empty?

    # Prefer strict JSON
    JSON.parse(text)
  rescue JSON::ParserError
    # Fallback: try to slice out the first {...} block.
    first = text.index("{")
    last = text.rindex("}")
    raise Error, "Gemini response did not contain JSON" if first.nil? || last.nil? || last <= first

    JSON.parse(text[first..last])
  end
  private_class_method :parse_jsonish
end

