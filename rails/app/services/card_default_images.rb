require "pathname"

class CardDefaultImages
  class Error < StandardError; end

  HANDS = %w[gu choki pa].freeze

  # GCS object key for starter/default janken images.
  #
  # Stored under the same env-prefix hierarchy as receipts/artworks:
  #   <env>/receipts/...
  #   <env>/card_artworks/...
  #   <env>/card_defaults/janken/<hand>.png   (this)
  def self.gcs_object_key_for(hand, env_prefix: Rails.env)
    h = hand.to_s
    raise Error, "invalid hand: #{hand.inspect}" unless HANDS.include?(h)
    raise Error, "env_prefix is blank" if env_prefix.to_s.strip.empty?

    [env_prefix, "card_defaults", "janken", "#{h}.png"].join("/")
  end

  # Local file path for default images (used for upload and local fallback).
  #
  # In docker-compose this repo mounts ./png to /png, but on host it may be under ../png.
  def self.local_path_for(hand)
    h = hand.to_s
    raise Error, "invalid hand: #{hand.inspect}" unless HANDS.include?(h)

    candidates = [
      Rails.root.join("..", "png", "#{h}.png"),
      Pathname.new("/png/#{h}.png")
    ]

    found = candidates.find { |p| File.exist?(p.to_s) }
    raise Error, "default image not found for #{h}. Put #{h}.png in ./png (or /png in container)" if found.nil?

    found.to_s
  end
end

