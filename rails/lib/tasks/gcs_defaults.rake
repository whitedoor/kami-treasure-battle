namespace :gcs do
  desc "Upload default janken images (gu/choki/pa) to GCS under <env>/card_defaults/janken/"
  task upload_janken_defaults: :environment do
    env_prefix = ENV.fetch("ENV_PREFIX", Rails.env).to_s
    overwrite = ENV["OVERWRITE"].to_s.strip == "1"

    result = GcsUploader.upload_default_janken_images!(env_prefix: env_prefix, overwrite: overwrite)

    puts "Bucket: #{result.fetch(:bucket)}"
    puts "Env prefix: #{env_prefix}"

    uploaded = result.fetch(:uploaded)
    skipped = result.fetch(:skipped)

    puts "Uploaded (#{uploaded.length}):"
    uploaded.each do |row|
      puts "  - #{row.fetch(:hand)} => #{row.fetch(:gcs_uri)} (generation=#{row.fetch(:generation)})"
    end

    puts "Skipped (#{skipped.length}):"
    skipped.each do |row|
      puts "  - #{row.fetch(:hand)} => #{row.fetch(:gcs_uri)} (generation=#{row.fetch(:generation)})"
    end
  end
end

namespace :card do
  desc "Backfill starter(normal) cards to use the default janken artwork object in GCS"
  task backfill_default_janken_artworks: :environment do
    bucket = ENV["GCS_BUCKET"].presence
    raise "ENV['GCS_BUCKET'] is not set" if bucket.blank?

    overwrite = ENV["OVERWRITE"].to_s.strip == "1"
    env_prefix = ENV.fetch("ENV_PREFIX", Rails.env).to_s

    scope =
      Card.where(rarity: "normal", attack_power: 10)
          .where(hand: CardDefaultImages::HANDS)

    updated = 0
    skipped = 0

    scope.find_each do |card|
      if !overwrite && card.artwork_status == "generated" && card.artwork_bucket.present? && card.artwork_object_key.present?
        skipped += 1
        next
      end

      key = CardDefaultImages.gcs_object_key_for(card.hand, env_prefix: env_prefix)
      card.update!(
        artwork_status: "generated",
        artwork_bucket: bucket,
        artwork_object_key: key,
        artwork_gcs_uri: "gs://#{bucket}/#{key}",
        artwork_mime_type: "image/png",
        artwork_model: "default"
      )
      updated += 1
    end

    puts "Env prefix: #{env_prefix}"
    puts "Updated: #{updated}"
    puts "Skipped: #{skipped}"
  end
end


