class HomeController < ApplicationController
  def index
  end

  def top_hero_image
    image_path = Rails.root.join("..", "png", "top.png")
    return head :not_found unless File.exist?(image_path)

    send_file image_path, type: "image/png", disposition: "inline"
  end

  def create_hero_image
    image_path = Rails.root.join("..", "png", "create.png")
    return head :not_found unless File.exist?(image_path)

    send_file image_path, type: "image/png", disposition: "inline"
  end
end

