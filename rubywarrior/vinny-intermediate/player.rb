require 'pry'
require 'memoist'

class Player
  def initialize
    @bound_enemies = []
    @freed_captives = []
  end

  def play_turn(warrior)
    Turn.new(warrior, self).play
  end

  def add_bound_enemy(space)
    @bound_enemies << space.location
  end

  def check_space_for_bound_enemy(space)
    @bound_enemies.include?(space.location)
  end

  def add_freed_captive(space)
    @freed_captives << space.location
  end

  def check_space_for_freed_captive(space)
    @freed_captives.include?(space.location)
  end
end

class Turn
  attr_reader :warrior
  def initialize(warrior, player)
    @warrior = warrior
    @state = TurnState.new(warrior, player)
    @strategy = Strategy.new(@state, warrior, player)
  end
  
  def play
    @strategy.play
  end
end

class Strategy
  attr_reader :state, :action

  def initialize(state, warrior, player)
    @state = state
    @action = Action.new(warrior, player)
  end

  def play
    return bind_an_enemy if multiply_threatened?
    return attack_an_enemy if threatened?
    return free_a_captive if captive_present?
    return rest if hurt?
    return attack_a_bound_enemy if bound_enemies_present?
    return walk_towards_stairs
  end

  def method_missing(meth)
    return @state.send(meth) if meth.to_s[-1] == '?'
    puts "taking action: #{meth}"
    return action.send(meth)
  end
end

class Action
  attr_reader :warrior, :player
  def initialize(warrior, player)
    @warrior = warrior
    @player = player
  end

  def directions
    [:forward, :left, :right, :backward]
  end

  def bind_an_enemy
    @player.add_bound_enemy(warrior.feel(find_unbound_enemy))
    @warrior.bind! find_unbound_enemy
  end

  def free_a_captive
    @player.add_freed_captive(warrior.feel(find_captive))
    @warrior.rescue! find_captive
  end

  def find_captive
    directions
      .reject{|direction| warrior.feel(direction).enemy? }
      .reject{|direction| @player.check_space_for_bound_enemy(warrior.feel(direction)) }
      .reject{|direction| @player.check_space_for_freed_captive(warrior.feel(direction)) }
      .find{|direction| warrior.feel(direction).captive? }    
  end

  def find_unbound_enemy
    directions.find do |direction|
      @warrior.feel(direction).enemy? && 
        !@warrior.feel(direction).captive?
    end
  end

  def attack_an_enemy
    @warrior.attack! find_unbound_enemy
  end
end

class TurnState
  extend Memoist

  attr_reader :warrior, :player
  def initialize(warrior, player)
    @warrior = warrior
    @player = player
  end

  def directions
    [:forward, :left, :right, :backward]
  end

  def multiply_threatened?
    number_of_threats > 1
  end

  def number_of_threats
    directions
      .collect{|direction| threat?(direction) }
      .select{|bool| bool == true }
      .count
  end

  def threat?(direction)
    @warrior.feel(direction).enemy? && 
    !@warrior.feel(direction).captive?
  end

  def threatened?
    number_of_threats > 0
  end

  def captive_present?
    directions
      .reject{|direction| warrior.feel(direction).enemy? }
      .reject{|direction| player.check_space_for_freed_captive(warrior.feel(direction)) }
      .find{|direction| warrior.feel(direction).captive? }
  end

  memoize :multiply_threatened?, :number_of_threats, :threatened?, :captive_present?
end

