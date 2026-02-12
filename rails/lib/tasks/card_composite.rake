namespace :card do
  desc "Compose frame + artwork into final card image (local test)"
  task compose: :environment do
    frame = ENV.fetch("FRAME")
    art = ENV.fetch("ART")
    out = ENV.fetch("OUT", Rails.root.join("tmp", "composed-card.png").to_s)

    art_box = {
      x: Integer(ENV.fetch("ART_X", "96")),
      y: Integer(ENV.fetch("ART_Y", "160")),
      width: Integer(ENV.fetch("ART_W", "576")),
      height: Integer(ENV.fetch("ART_H", "576"))
    }

    CardComposer.compose!(
      frame_path: frame,
      artwork_path: art,
      out_path: out,
      art_box: art_box
    )

    puts "Wrote: #{out}"
  end
end

