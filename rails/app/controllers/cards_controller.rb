require "fileutils"

class CardsController < ApplicationController
  def show
    @card = card_scope.find(params[:id])
  end

  def image
    card = card_scope.find(params[:id])
    if card.artwork_status == "generated" && card.artwork_bucket.present? && card.artwork_object_key.present?
      storage = GcsUploader.send(:build_storage)
      bucket = storage.bucket(card.artwork_bucket)
      file = bucket&.file(card.artwork_object_key)

      if file.present?
        tmp_dir = Rails.root.join("tmp", "card_artworks_cache")
        FileUtils.mkdir_p(tmp_dir)
        tmp_path = tmp_dir.join("#{card.id}.png")
        file.download(tmp_path.to_s)
        return send_file tmp_path.to_s, type: card.artwork_mime_type.presence || "image/png", disposition: "inline"
      end
    end

    # fallback: placeholder-based image
    path = CardImageGenerator.generate!(card)
    send_file path, type: "image/png", disposition: "inline"
  rescue CardImageGenerator::Error => e
    render plain: e.message, status: :unprocessable_entity
  end

  def generate_artwork
    card = card_scope.find(params[:id])
    CardArtworkGenerator.generate_for_card!(card)
    redirect_to card_path(card), notice: "画像生成が完了しました"
  rescue CardArtworkGenerator::Error => e
    redirect_to card_path(card), alert: "画像生成に失敗: #{e.message}"
  end

  private

  def card_scope
    Card.joins(:receipt_upload).where(receipt_uploads: { user_id: current_user.id })
  end
end

