require "fileutils"
require "securerandom"
require "zlib"

class CardArtworkGenerator
  class Error < StandardError; end
  class TransientError < Error; end

  def self.generate_for_card!(card)
    raise Error, "card is required" if card.nil?
    return card if card.artwork_status == "generated" && card.artwork_gcs_uri.present?

    bucket_name = ENV["GCS_BUCKET"].to_s
    raise Error, "ENV['GCS_BUCKET'] is not set" if bucket_name.blank?

    card.update!(artwork_status: "generating", artwork_error: nil)

    prompt = build_prompt(card)
    seed = deterministic_seed(card)
    generated = VertexImagenGenerator.generate!(prompt: prompt, mime_type: "image/png", seed: seed)

    dir = Rails.root.join("tmp", "card_artworks")
    FileUtils.mkdir_p(dir)
    local_path = dir.join("#{card.id}-#{SecureRandom.uuid}.png")
    File.binwrite(local_path, generated.fetch(:bytes))

    storage = GcsUploader.send(:build_storage)
    bucket = storage.bucket(bucket_name)
    raise Error, "GCS bucket not found: #{bucket_name.inspect}" if bucket.nil?

    object_key = [
      Rails.env,
      "card_artworks",
      Time.now.utc.strftime("%Y/%m/%d"),
      "#{card.id}-#{SecureRandom.uuid}.png"
    ].join("/")

    file = bucket.create_file(local_path.to_s, object_key, content_type: "image/png")

    card.update!(
      artwork_status: "generated",
      artwork_bucket: bucket_name,
      artwork_object_key: object_key,
      artwork_gcs_uri: "gs://#{bucket_name}/#{object_key}",
      artwork_generation: file.generation,
      artwork_mime_type: "image/png",
      artwork_model: generated[:model],
      artwork_prompt: generated[:prompt]
    )

    card
  rescue VertexImagenGenerator::Error => e
    # Transient failures: retryable (quota, rate limiting, temporary service issues).
    msg = e.message.to_s
    transient =
      msg.match?(/quota exceeded|resource_exhausted|rate|429|unavailable|deadline|timeout/i)

    if transient
      # Keep it in "generating" so the UI can keep polling for a while.
      card.update(artwork_status: "generating", artwork_error: msg) if card&.persisted?
      raise TransientError, msg
    end

    card.update(artwork_status: "failed", artwork_error: msg) if card&.persisted?
    raise Error, msg
  rescue StandardError => e
    card.update(artwork_status: "failed", artwork_error: e.message) if card&.persisted?
    raise
  end

  def self.build_prompt(card)
    <<~PROMPT
      日本のファンタジーTCGのカード用アートを生成してください。正方形(1:1)。
      テーマ: #{card.name} の概念/イメージ（重要: 画像内にタイトル等の文字として描かない）。
      雰囲気: #{card.flavor.presence || "魔法を唱えている感、神秘的、宝探し"}。
      スタイル: 高品質なデジタルイラスト、強い光のエフェクト、魔法陣、粒子、幻想的、背景込み。
      制約:
      - 人物・顔・手など人間の要素は入れない
      - 文字は絶対に入れない（ひらがな/カタカナ/漢字/アルファベット/数字/記号/ルーン/象形文字/手書き文字/看板/ラベル/スタンプ/印章/署名/透かし/ロゴ/ウォーターマーク/UI/キャプション/タイポグラフィを含む）
      - no text, no letters, no numbers, no logo, no watermark, no signature, no UI
      - 単色ベタではなく情報量のある絵にする
    PROMPT
  end
  private_class_method :build_prompt

  def self.deterministic_seed(card)
    Zlib.crc32("#{card.id}-#{card.name}-#{card.hand}-#{card.attack_power}-#{card.rarity}") % 2**32
  end
  private_class_method :deterministic_seed
end

