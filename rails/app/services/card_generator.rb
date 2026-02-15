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
    name = fallback_name_from_items(extracted) if name.empty?
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

  def self.fallback_name_from_items(extracted)
    items = extracted.is_a?(Hash) ? extracted["items"] : nil
    first = items.is_a?(Array) ? items.first : nil
    base = first.is_a?(Hash) ? first["name"].to_s.strip : ""
    base.presence || "謎のレシート"
  end
  private_class_method :fallback_name_from_items

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

