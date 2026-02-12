require "vips"

class CardComposer
  # Frame（枠）は透過PNG想定。Artwork（生成画像）はjpg/pngどちらでもOK。
  #
  # art_box: 枠画像の上にアートを配置する領域（px）
  # - x,y: 左上座標
  # - width,height: 配置サイズ（このサイズにcoverでフィット）
  #
  # 出力画像サイズは基本的にframeのサイズを採用します（frameと同サイズで合成）。
  def self.compose!(frame_path:, artwork_path:, out_path:, art_box:)
    frame = Vips::Image.new_from_file(frame_path, access: :sequential)
    artwork = Vips::Image.new_from_file(artwork_path, access: :sequential)

    canvas_w = frame.width
    canvas_h = frame.height

    fitted = fit_cover(artwork, width: art_box.fetch(:width), height: art_box.fetch(:height))
    fitted = ensure_alpha(fitted)

    placed = fitted.embed(
      art_box.fetch(:x),
      art_box.fetch(:y),
      canvas_w,
      canvas_h,
      extend: :background,
      background: [0, 0, 0, 0]
    )

    placed = ensure_bands_match(placed, frame)
    frame = ensure_bands_match(frame, placed)

    composed = placed.composite2(frame, :over)
    composed.write_to_file(out_path)
  end

  def self.fit_cover(image, width:, height:)
    scale = [width.to_f / image.width, height.to_f / image.height].max
    resized = image.resize(scale)

    left = [(resized.width - width) / 2, 0].max
    top = [(resized.height - height) / 2, 0].max

    resized.crop(left, top, width, height)
  end
  private_class_method :fit_cover

  def self.ensure_alpha(image)
    image.hasalpha? ? image : image.addalpha
  end
  private_class_method :ensure_alpha

  def self.ensure_bands_match(a, b)
    # compositeはバンド数（RGB/RGBA）が一致している必要があるため揃える
    return a if a.bands == b.bands

    if a.bands == 3 && b.bands == 4
      a.addalpha
    elsif a.bands == 4 && b.bands == 3
      a.extract_band(0, n: 3)
    else
      a
    end
  end
  private_class_method :ensure_bands_match
end

