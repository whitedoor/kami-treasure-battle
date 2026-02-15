require "fileutils"
require "digest"
require "tmpdir"

class CardsController < ApplicationController
  def show
    @card = card_scope.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        render json: {
          ok: true,
          card: @card.as_json(
            only: %i[id name hand attack_power rarity artwork_status artwork_error artwork_bucket artwork_object_key artwork_gcs_uri]
          )
        }
      end
    end
  end

  def image
    card = card_scope.find(params[:id])

    etag_seed = [
      "card-image",
      card.id,
      card.artwork_status,
      card.artwork_bucket,
      card.artwork_object_key,
      card.artwork_generation,
      card.updated_at.to_i
    ].join(":")

    # If the URL contains a version (v=...), we can cache much longer in the browser safely.
    if params[:v].present? && card.artwork_status == "generated"
      response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    else
      response.headers["Cache-Control"] = "public, max-age=300"
    end

    return unless stale?(etag: etag_seed, last_modified: card.updated_at, public: true)

    if card.artwork_status == "generated" && card.artwork_bucket.present? && card.artwork_object_key.present?
      begin
        storage = GcsUploader.send(:build_storage)
        bucket = storage.bucket(card.artwork_bucket)
        file = bucket&.file(card.artwork_object_key)

        if file.present?
          # Cloud Run filesystem is read-only except /tmp.
          tmp_dir = Pathname.new(Dir.tmpdir).join("card_artworks_cache")
          FileUtils.mkdir_p(tmp_dir)
          key_hash = Digest::SHA256.hexdigest(card.artwork_object_key.to_s)[0, 12]
          gen = card.artwork_generation.presence || 0
          out_path = tmp_dir.join("#{card.id}-#{gen}-#{key_hash}.png")
          unless File.exist?(out_path)
            tmp_path = out_path.sub_ext(".tmp.png")
            file.download(tmp_path.to_s)
            FileUtils.mv(tmp_path, out_path)
          end

          return send_file out_path.to_s, type: card.artwork_mime_type.presence || "image/png", disposition: "inline"
        end
      rescue Google::Cloud::PermissionDeniedError, Google::Cloud::NotFoundError, Google::Apis::ClientError => e
        Rails.logger.warn("GCS artwork fetch failed for card=#{card.id} bucket=#{card.artwork_bucket} key=#{card.artwork_object_key}: #{e.class}: #{e.message}")
        # Fall through to placeholder-based image.
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

    if card.artwork_status == "generated"
      respond_to do |format|
        format.html { redirect_to card_path(card), notice: "画像は生成済みです" }
        format.json { render json: { ok: true, status: "generated", redirect_to: card_path(card) } }
      end
      return
    end

    if card.artwork_status == "generating"
      # If it looks stuck, allow re-trigger.
      # (e.g. enqueue failed previously, instance was killed, etc.)
      if card.updated_at < 10.minutes.ago
        card.update!(artwork_status: "failed", artwork_error: "生成がタイムアウトしました。もう一度お試しください。")
      else
      respond_to do |format|
        format.html { redirect_to card_path(card), notice: "画像生成中です" }
        format.json { render json: { ok: true, status: "generating", redirect_to: card_path(card) } }
      end
      return
      end
    end

    # pending/failed などはキューに積んで即時返す（ページ遷移と同時に開始したい）
    card.update!(artwork_status: "generating", artwork_error: nil)
    GenerateCardArtworkJob.perform_later(card.id)

    respond_to do |format|
      format.html { redirect_to card_path(card), notice: "画像生成を開始しました" }
      format.json { render json: { ok: true, status: "generating", redirect_to: card_path(card) } }
    end
  rescue CardArtworkGenerator::Error => e
    respond_to do |format|
      format.html { redirect_to card_path(card), alert: "画像生成に失敗: #{e.message}" }
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def card_scope
    Card.joins(:receipt_upload).where(receipt_uploads: { user_id: current_user.id })
  end
end

