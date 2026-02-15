module Battle
  class Engine
    INITIAL_HP = 200
    TIE_DAMAGE = (INITIAL_HP * 0.05).to_i # 10
    HANDS = %w[gu choki pa].freeze

    class Error < StandardError; end

    def start!(player:, player_loadout:)
      validate_loadout!(player, player_loadout)

      cpu_loadout = build_cpu_loadout!

      {
        version: 1,
        started_at: Time.current.to_i,
        ended: false,
        initial_hp: INITIAL_HP,
        tie_damage: TIE_DAMAGE,
        player_hp: INITIAL_HP,
        cpu_hp: INITIAL_HP,
        player_loadout: stringify_keys(player_loadout),
        cpu_loadout: cpu_loadout,
        turns: []
      }
    end

    def play_turn!(state:, player_hand:)
      raise Error, "battle has ended" if state.fetch(:ended)
      raise Error, "invalid hand" unless HANDS.include?(player_hand)

      cpu_hand = HANDS.sample

      player_card = card_for_hand!(state.fetch(:player_loadout), player_hand)
      cpu_card = card_for_hand!(state.fetch(:cpu_loadout), cpu_hand)

      outcome = outcome_for(player_hand, cpu_hand)

      player_damage = 0
      cpu_damage = 0

      case outcome
      when :player
        cpu_damage = player_card.attack_power
      when :cpu
        player_damage = cpu_card.attack_power
      when :tie
        player_damage = state.fetch(:tie_damage)
        cpu_damage = state.fetch(:tie_damage)
      else
        raise Error, "unexpected outcome"
      end

      next_player_hp = [state.fetch(:player_hp) - player_damage, 0].max
      next_cpu_hp = [state.fetch(:cpu_hp) - cpu_damage, 0].max

      next_state = state.deep_dup
      next_state[:player_hp] = next_player_hp
      next_state[:cpu_hp] = next_cpu_hp

      turn = {
        player_hand: player_hand,
        cpu_hand: cpu_hand,
        outcome: outcome.to_s,
        player_damage: player_damage,
        cpu_damage: cpu_damage,
        player_hp_after: next_player_hp,
        cpu_hp_after: next_cpu_hp
      }

      next_state[:turns] ||= []
      next_state[:turns] << turn
      # CookieStoreのセッションが肥大化すると更新が不安定になるため、直近だけ保持する
      next_state[:turns] = next_state[:turns].last(10)

      if next_player_hp <= 0 || next_cpu_hp <= 0
        next_state[:ended] = true
        next_state[:winner] =
          if next_player_hp <= 0 && next_cpu_hp <= 0
            "draw"
          elsif next_cpu_hp <= 0
            "player"
          else
            "cpu"
          end
      end

      next_state
    end

    private

    def validate_loadout!(player, loadout)
      raise Error, "loadout required" unless loadout.is_a?(Hash)
      HANDS.each do |hand|
        key = "#{hand}_card_id"
        raise Error, "#{key} required" if loadout[key].blank? && loadout[key.to_sym].blank?
      end

      ids = HANDS.map { |hand| loadout["#{hand}_card_id"] || loadout[:"#{hand}_card_id"] }
      cards = player.cards.where(id: ids)
      raise Error, "invalid loadout (not owned)" unless cards.size == 3

      cards_by_id = cards.index_by { |c| c.id.to_s }
      HANDS.each do |hand|
        id = (loadout["#{hand}_card_id"] || loadout[:"#{hand}_card_id"]).to_s
        card = cards_by_id.fetch(id)
        raise Error, "hand mismatch for #{hand}" unless card.hand == hand
      end
    end

    def build_cpu_loadout!
      loadout = {}
      HANDS.each do |hand|
        card = Card.where(hand: hand).order(Arel.sql("RANDOM()")).first
        raise Error, "no cards exist for hand=#{hand}" if card.nil?
        loadout["#{hand}_card_id"] = card.id
      end
      loadout
    end

    def card_for_hand!(loadout, hand)
      id = loadout["#{hand}_card_id"] || loadout[:"#{hand}_card_id"]
      raise Error, "missing card id for hand=#{hand}" if id.blank?
      Card.find(id)
    end

    # returns :player, :cpu, :tie
    def outcome_for(player_hand, cpu_hand)
      return :tie if player_hand == cpu_hand

      win =
        (player_hand == "gu" && cpu_hand == "choki") ||
          (player_hand == "choki" && cpu_hand == "pa") ||
          (player_hand == "pa" && cpu_hand == "gu")

      win ? :player : :cpu
    end

    def stringify_keys(hash)
      hash.to_h.transform_keys(&:to_s)
    end
  end
end

