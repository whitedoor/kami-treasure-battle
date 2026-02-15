require "fileutils"

class CardsController < ApplicationController
  def show
    @card = Card.find(params[:id])
  end

  def image
    card = Card.find(params[:id])
    if card.artwork_status == "generated" && card.artwork_bucket.present? && card.artwork_object_key.present?
      storage = GcsUploader.send(:build_storage)
      bucket = storage.bucket(card.artwork_bucket)
      file = bucket&.file(card.artwork_object_key)
      return render(plain: "artwork not found in GCS", status: :not_found) if file.nil?

      tmp_dir = Rails.root.join("tmp", "card_artworks_cache")
      FileUtils.mkdir_p(tmp_dir)
      tmp_path = tmp_dir.join("#{card.id}.png")
      file.download(tmp_path.to_s)
      return send_file tmp_path.to_s, type: card.artwork_mime_type.presence || "image/png", disposition: "inline"
    end

    # fallback: placeholder-based image
    path = CardImageGenerator.generate!(card)
    send_file path, type: "image/png", disposition: "inline"
  rescue CardImageGenerator::Error => e
    render plain: e.message, status: :unprocessable_entity
  end

  def generate_artwork
    card = Card.find(params[:id])
    CardArtworkGenerator.generate_for_card!(card)
    redirect_to card_path(card), notice: "画像生成が完了しました"
  rescue CardArtworkGenerator::Error => e
    redirect_to card_path(card), alert: "画像生成に失敗: #{e.message}"
  end
end

