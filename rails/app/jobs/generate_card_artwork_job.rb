class GenerateCardArtworkJob < ApplicationJob
  queue_as :default

  # Imagen / Vertex quotas can hit transient 429s. Retry a few times with backoff.
  retry_on CardArtworkGenerator::TransientError,
           wait: ->(executions) { [10, 20, 40, 80, 160, 320][executions] || 600 },
           attempts: 8

  def perform(card_id)
    card = Card.find_by(id: card_id)
    return if card.nil?

    # Idempotent-ish: generator short-circuits when already generated.
    CardArtworkGenerator.generate_for_card!(card)
  end
end

