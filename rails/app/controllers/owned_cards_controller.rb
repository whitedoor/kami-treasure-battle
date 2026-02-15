class OwnedCardsController < ApplicationController
  def index
    @owned_cards = current_user.owned_cards.includes(:card).order(created_at: :desc)
  end
end

