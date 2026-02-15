class BattlesController < ApplicationController
  def new
    @gu_cards = current_user.cards.where(hand: "gu").order(created_at: :desc)
    @choki_cards = current_user.cards.where(hand: "choki").order(created_at: :desc)
    @pa_cards = current_user.cards.where(hand: "pa").order(created_at: :desc)
  end

  def create
    engine = Battle::Engine.new
    state = engine.start!(player: current_user, player_loadout: loadout_params.to_h)
    # CPUはユーザーのスターターカード（normal）をデフォルトとして使用する
    # ※見つからない場合のみ、Engine側のランダムロードアウトにフォールバック
    state[:cpu_loadout] = default_cpu_loadout_for(current_user) || state[:cpu_loadout]
    save_battle_state!(state)
    redirect_to battle_path, notice: "バトルを開始しました（HP: 200）"
  rescue Battle::Engine::Error => e
    redirect_to new_battle_path, alert: "バトル開始に失敗: #{e.message}"
  end

  def show
    @battle_state = battle_state
    if @battle_state.nil?
      redirect_to new_battle_path, alert: "先にバトルを開始してください"
      return
    end

    player_ids = %w[gu choki pa].map { |hand| @battle_state.dig(:player_loadout, :"#{hand}_card_id") }.compact
    cpu_ids = %w[gu choki pa].map { |hand| @battle_state.dig(:cpu_loadout, :"#{hand}_card_id") }.compact
    cards = Card.where(id: (player_ids + cpu_ids)).index_by { |c| c.id.to_s }

    @player_cards = {
      "gu" => cards[@battle_state.dig(:player_loadout, :gu_card_id)&.to_s],
      "choki" => cards[@battle_state.dig(:player_loadout, :choki_card_id)&.to_s],
      "pa" => cards[@battle_state.dig(:player_loadout, :pa_card_id)&.to_s]
    }

    @cpu_cards = {
      "gu" => cards[@battle_state.dig(:cpu_loadout, :gu_card_id)&.to_s],
      "choki" => cards[@battle_state.dig(:cpu_loadout, :choki_card_id)&.to_s],
      "pa" => cards[@battle_state.dig(:cpu_loadout, :pa_card_id)&.to_s]
    }
  end

  def turn
    state = battle_state
    return redirect_to(new_battle_path, alert: "先にバトルを開始してください") if state.nil?

    engine = Battle::Engine.new
    next_state = engine.play_turn!(state: state, player_hand: params[:hand].to_s)
    save_battle_state!(next_state)

    redirect_to battle_path
  rescue Battle::Engine::Error => e
    redirect_to battle_path, alert: "ターン処理に失敗: #{e.message}"
  end

  def destroy
    session.delete(:battle_state)
    redirect_to new_battle_path, notice: "バトルをリセットしました"
  end

  private

  def loadout_params
    params.require(:loadout).permit(:gu_card_id, :choki_card_id, :pa_card_id)
  end

  def battle_state
    raw = session[:battle_state]
    raw.is_a?(Hash) ? raw.deep_symbolize_keys : nil
  end

  def save_battle_state!(state)
    session[:battle_state] = state.deep_stringify_keys
  end

  # returns {"gu_card_id"=>1,"choki_card_id"=>2,"pa_card_id"=>3} or nil
  def default_cpu_loadout_for(user)
    hands = %w[gu choki pa]
    loadout = {}

    hands.each do |hand|
      card = user.cards.where(hand: hand, rarity: "normal").order(created_at: :asc).first
      return nil if card.nil?
      loadout["#{hand}_card_id"] = card.id
    end

    loadout
  end
end

