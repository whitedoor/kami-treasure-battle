class GenerateCardArtworkJob < ApplicationJob
  queue_as :default

  def perform(card_id)
    card = Card.find_by(id: card_id)
    return if card.nil?

    # Idempotent-ish: generator short-circuits when already generated.
    CardArtworkGenerator.generate_for_card!(card)
  end
end

