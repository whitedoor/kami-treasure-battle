require "fileutils"
require "vips"

class CardImageGenerator
  class Error < StandardError; end

  SIZE = 768

  # Generates a square PNG for the given card and returns the file path.
  # For MVP, we just crop/fit a placeholder artwork image.
  def self.generate!(card)
    raise Error, "card is required" if card.nil?

    dir = Rails.root.join("tmp", "card_images")
    FileUtils.mkdir_p(dir)

    out_path = dir.join("#{card.id}.png")
    return out_path.to_s if File.exist?(out_path)

    artwork_path =
      ENV["CARD_ARTWORK_PATH"].presence ||
      Dir["/png/*.{png,webp,jpg,jpeg}"].sort.first

    raise Error, "no artwork found. Put an image in /png or set CARD_ARTWORK_PATH" if artwork_path.blank?

    artwork = Vips::Image.new_from_file(artwork_path, access: :sequential)
    square = fit_cover(artwork, width: SIZE, height: SIZE)

    tmp_path = out_path.sub_ext(".tmp.png")
    square.write_to_file(tmp_path.to_s)
    FileUtils.mv(tmp_path, out_path)

    out_path.to_s
  end

  def self.fit_cover(image, width:, height:)
    scale = [width.to_f / image.width, height.to_f / image.height].max
    resized = image.resize(scale)

    left = [(resized.width - width) / 2, 0].max
    top = [(resized.height - height) / 2, 0].max

    resized.crop(left, top, width, height)
  end
  private_class_method :fit_cover
end

