require "zlib"

class CardGenerator
  class Error < StandardError; end

  # Deterministic "weighted random" based on receipt_upload identity,
  # so replays don't change attack/rarity.
  #
  # Weights (per-mille):
  # - 20: 600
  # - 30: 250
  # - 40: 120
  # - 50: 30
  def self.generate_for_receipt_upload!(receipt_upload)
    raise Error, "receipt_upload is required" if receipt_upload.nil?

    existing = receipt_upload.card
    return existing if existing

    extracted = receipt_upload.extracted_json || {}
    card_hash = extracted.is_a?(Hash) ? (extracted["card"] || {}) : {}

    name = card_hash["name"].to_s.strip
    name = fantasy_name_avoiding_item_chars(extracted) if name.empty?
    name = fantasy_name_avoiding_item_chars(extracted) if shares_any_item_char?(name, extracted)
    raise Error, "card.name is blank" if name.empty?

    hand = normalize_hand(card_hash["hand"])
    flavor = card_hash["flavor"].to_s

    attack_power = deterministic_attack_power(receipt_upload)
    rarity = rarity_for_attack_power(attack_power)

    Card.transaction do
      card = Card.create!(
        receipt_upload: receipt_upload,
        name: name,
        hand: hand,
        flavor: flavor,
        attack_power: attack_power,
        rarity: rarity
      )
      OwnedCard.create!(card: card, user: receipt_upload.user)
      card
    end
  end

  def self.fantasy_name_avoiding_item_chars(extracted)
    forbidden = forbidden_chars_from_items(extracted)
    seed = Zlib.crc32(forbidden.to_a.sort.join)

    # なるべく被りにくい「カタカナ/英単語」で構成（漢字・ひらがなを使わない）
    # NOTE: items[*].name と1文字でも被るとNGなので、語彙は短め＆種類多めにして当たりやすくする。
    prefixes_all = %w[
      ARCANE SHADOW NEON VOID ASTRAL ECHO NOVA SIGMA ORBIT PHANTOM MIRAGE FROST STORM ONYX IVORY CRIMSON EMERALD
    ].freeze
    cores_all = %w[
      SIGIL ORB RUNE SEAL HEX CHANT AURA GATE CROWN BLADE VEIL NEXUS CORE SPARK WAVE GLYPH
      シジル オーブ ルーン シール ヘクス オーラ ゲート クラウン ブレード ヴェール ネクサス コア スパーク ウェーブ グリフ
    ].freeze
    suffixes_all = %w[
      BURST AWAKENING RESONANCE UNLEASH SUMMON SHIFT OVERDRIVE AMPLIFY LINK
      バースト アウェイク レゾナンス アンリーシュ サモン シフト オーバードライブ アンプ リンク
    ].freeze
    separators = ["・", "：", "／"].freeze # 記号は比較対象外（禁止文字に含めない）

    prefixes = prefixes_all.reject { |w| word_forbidden?(w, forbidden) }
    cores = cores_all.reject { |w| word_forbidden?(w, forbidden) }
    suffixes = suffixes_all.reject { |w| word_forbidden?(w, forbidden) }

    prefix = pick_deterministic(prefixes.presence || prefixes_all, seed: seed, salt: 1)
    core = pick_deterministic(cores.presence || cores_all, seed: seed, salt: 2)
    suffix = pick_deterministic(suffixes.presence || suffixes_all, seed: seed, salt: 3)
    sep = pick_deterministic(separators, seed: seed, salt: 4)

    candidate = "#{prefix}#{sep}#{core}#{suffix}"

    # 最終チェック（1文字でも被ったら別候補を試す）
    return candidate[0, 18] unless shares_any_item_char?(candidate, extracted)

    alt_words = (%w[ARC SHD NVX VLT AST ECH NVA SGN ORB RUN] + prefixes_all + cores_all).uniq
    12.times do |i|
      a = pick_deterministic(alt_words, seed: seed, salt: 10 + i)
      b = pick_deterministic(alt_words, seed: seed, salt: 30 + i)
      c = pick_deterministic(suffixes_all, seed: seed, salt: 50 + i)
      attempt = "#{a}#{separators[i % separators.length]}#{b}#{c}"
      return attempt[0, 18] unless shares_any_item_char?(attempt, extracted)
    end

    # どうしても無理なら、商品名と被りにくい「記号のみ」に逃がす（漢字を含めない）
    # 記号は比較対象外なので、衝突しづらい最終手段として使う。
    fallback = "◆◇◆"
    shares_any_item_char?(fallback, extracted) ? "◆◆◆" : fallback
  end
  private_class_method :fantasy_name_avoiding_item_chars

  def self.pick_deterministic(list, seed:, salt:)
    list = Array(list)
    return "" if list.empty?
    idx = Zlib.crc32("#{seed}-#{salt}") % list.length
    list[idx].to_s
  end
  private_class_method :pick_deterministic

  def self.forbidden_chars_from_items(extracted)
    items = extracted.is_a?(Hash) ? extracted["items"] : nil
    return Set.new unless items.is_a?(Array)
    begin
      require "set"
    rescue LoadError
      # fallthrough
    end
    set = defined?(Set) ? Set.new : []

    items.each do |it|
      next unless it.is_a?(Hash)
      raw = it["name"].to_s
      norm = normalize_for_compare(raw)
      each_significant_char(norm) { |ch| set << ch }
    end

    set
  end
  private_class_method :forbidden_chars_from_items

  def self.word_forbidden?(word, forbidden_set)
    return false if forbidden_set.nil?
    chars = []
    each_significant_char(word) { |ch| chars << ch }
    chars.any? { |ch| forbidden_set.include?(ch) }
  end
  private_class_method :word_forbidden?

  def self.each_significant_char(text)
    return enum_for(:each_significant_char, text) unless block_given?
    norm = normalize_for_compare(text)
    norm.each_char do |ch|
      # 文字レベル禁止: 日本語（ひら/カタ/漢字）+ 英数
      next unless ch.match?(/[\p{Hiragana}\p{Katakana}\p{Han}A-Za-z0-9]/)
      yield ch
    end
  end
  private_class_method :each_significant_char

  def self.normalize_for_compare(text)
    text.to_s.unicode_normalize(:nfkc).downcase.strip
  rescue StandardError
    text.to_s.downcase.strip
  end
  private_class_method :normalize_for_compare

  def self.shares_any_item_char?(card_name, extracted)
    cn = normalize_for_compare(card_name)
    return true if cn.blank?

    forbidden = forbidden_chars_from_items(extracted)
    each_significant_char(cn) do |ch|
      return true if forbidden.include?(ch)
    end
    false
  end
  private_class_method :shares_any_item_char?

  def self.normalize_hand(raw)
    v = raw.to_s.strip
    return v if Card::HANDS.include?(v)

    # allow Japanese variants just in case
    case v
    when "ぐー", "グー", "guu" then "gu"
    when "ちょき", "チョキ" then "choki"
    when "ぱー", "パー" then "pa"
    else
      "gu"
    end
  end
  private_class_method :normalize_hand

  def self.deterministic_attack_power(receipt_upload)
    seed = Zlib.crc32("#{receipt_upload.id}-#{receipt_upload.gcs_bucket}-#{receipt_upload.gcs_object_key}-#{receipt_upload.gcs_generation}")
    r = seed % 1000

    case r
    when 0...600 then 20
    when 600...850 then 30
    when 850...970 then 40
    else 50
    end
  end
  private_class_method :deterministic_attack_power

  def self.rarity_for_attack_power(attack_power)
    case attack_power
    when 20 then "bronze"
    when 30 then "silver"
    when 40 then "gold"
    when 50 then "legend"
    else
      raise Error, "invalid attack_power: #{attack_power.inspect}"
    end
  end
  private_class_method :rarity_for_attack_power
end

