
module Rainbow

  # Retrieve ANSI color code from a color name, an html color
  # or an RGB color
  class AnsiColor

    # +ground+ is one of :foreground, :background
    # +color+ is one of this 3 formats: name, html, rgb
    def initialize(ground, *color)
      @ground = ground

      if color.size == 1
        @color = color.first
      else
        @color = color
      end
    end

    # Get the ANSI color code.
    def code
      case @color
        when Symbol then code_from_name
        when String then code_from_html
        when Array then code_from_rgb
      end
    end

    private

    def code_from_name #:nodoc:
      validate_color_name

      TERM_COLORS[@color] + (@ground == :foreground ? 30 : 40)
    end

    def code_from_html #:nodoc:
      @color = @color.gsub("#", "")
      AnsiRgb.new(@ground, rgb_from_html).code
    end

    def rgb_from_html #:nodoc:
      red = @color[0..1].to_i(16)
      green = @color[2..3].to_i(16)
      blue = @color[4..5].to_i(16)
      [red, green, blue]
    end

    def code_from_rgb #:nodoc:
      unless @color.size == 3
        raise ArgumentError.new \
          "Bad number of arguments for RGB color definition, should be 3"
      end

      AnsiRgb.new(@ground, @color).code
    end

    def validate_color_name #:nodoc:
      color_names = TERM_COLORS.keys

      unless color_names.include?(@color)
        raise ArgumentError.new \
          "Unknown color name, valid names: #{color_names.join(', ')}"
      end
    end

  end

  # Retrieve ANSI color code from RGB color.
  class AnsiRgb

    # +ground+ is one of :foreground, :background
    # +rgb+ is an array of 3 values between 0 and 255.
    def initialize(ground, rgb)
      if RGB.outside_range?(rgb)
        raise ArgumentError.new("RGB value outside 0-255 range")
      end

      @ground_code = { :foreground => 38, :background => 48 }[ground]
      @red, @green, @blue = rgb[0], rgb[1], rgb[2]
    end

    # Get the ANSI color code for this RGB color.
    def code
      index = 16 +
              RGB.to_ansi_domain(@red) * 36 +
              RGB.to_ansi_domain(@green) * 6 +
              RGB.to_ansi_domain(@blue)

      "#{@ground_code};5;#{index}"
    end

  end

  # Helper class for RGB color format.
  class RGB
    def self.outside_range?(rgb)
      rgb.min < 0 or rgb.max > 255
    end

    # Change domain of color value from 0-255 to 0-5
    def self.to_ansi_domain(value)
      (6 * (value / 256.0)).to_i
    end
  end

  class << self; attr_accessor :enabled; end
  @enabled = STDOUT.tty? && ENV['TERM'] != 'dumb' || ENV['CLICOLOR_FORCE'] == '1'

  TERM_COLORS = {
    :black => 0,
    :red => 1,
    :green => 2,
    :yellow => 3,
    :blue => 4,
    :magenta => 5,
    :cyan => 6,
    :white => 7,
    :default => 9,
  }

  TERM_EFFECTS = {
    :reset => 0,
    :bright => 1,
    :italic => 3,
    :underline => 4,
    :blink => 5,
    :inverse => 7,
    :hide => 8,
  }

  # Sets foreground color of this text.
  def foreground(*color)
    wrap_with_code(AnsiColor.new(:foreground, *color).code)
  end
  alias_method :color, :foreground
  alias_method :colour, :foreground


  # Sets background color of this text.
  def background(*color)
    wrap_with_code(AnsiColor.new(:background, *color).code)
  end

  # Resets terminal to default colors/backgrounds.
  #
  # It shouldn't be needed to use this method because all methods
  # append terminal reset code to end of string.
  def reset
    wrap_with_code(TERM_EFFECTS[:reset])
  end

  # Turns on bright/bold for this text.
  def bright
    wrap_with_code(TERM_EFFECTS[:bright])
  end

  # Turns on italic style for this text (not well supported by terminal
  # emulators).
  def italic
    wrap_with_code(TERM_EFFECTS[:italic])
  end

  # Turns on underline decoration for this text.
  def underline
    wrap_with_code(TERM_EFFECTS[:underline])
  end

  # Turns on blinking attribute for this text (not well supported by terminal
  # emulators).
  def blink
    wrap_with_code(TERM_EFFECTS[:blink])
  end

  # Inverses current foreground/background colors.
  def inverse
    wrap_with_code(TERM_EFFECTS[:inverse])
  end

  # Hides this text (set its color to the same as background).
  def hide
    wrap_with_code(TERM_EFFECTS[:hide])
  end

  private

  def wrap_with_code(code) #:nodoc:
    return self unless Rainbow.enabled

    var = self.dup
    matched = var.match(/^(\e\[([\d;]+)m)*/)
    var.insert(matched.end(0), "\e[#{code}m")
    var.concat("\e[0m") unless var =~ /\e\[0m$/
    var
  end
end


String.send(:include, Rainbow)

# On Windows systems, try to load the local ANSI support library
if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
  begin
    require 'Win32/Console/ANSI'
  rescue LoadError
    Rainbow.enabled = false
  end
end

# -----||-----------------------------------
#      ||
#      ||    RUBY SCROLLS
#      ||
# =====||===================================


# -----||-----------------------------------
#      ||    PROMPT CUSTOMIZATION
# =====||===================================

IRB.conf[:PROMPT][:CUSTOM] = {
  :PROMPT_I => "\n>> ".color(:green),
  :PROMPT_S => "%l>> ".color(:green),
  :PROMPT_C => ".. ",
  :PROMPT_N => ".. ",
  :RETURN => "\n=> ".color(:blue) + "%s\n"
}
IRB.conf[:PROMPT_MODE] = :CUSTOM
IRB.conf[:AUTO_INDENT] = true

# -----||-----------------------------------
#      ||    GLOBAL METHODS
# =====||===================================

module Kernel
  def word_wrap(text, col_width=70)
     text.gsub!( /(\S{#{col_width}})(?=\S)/, '\1 ' )
     text.gsub!( /(.{1,#{col_width}})(?:\s+|$)/, "\\1\n" )
     text
  end

  def say(text)
    puts word_wrap(text)
  end
end

def print_error(message)
  say "\n" + message.color(:red)

  "Try again."
end

def print_success(message)
  say "\n" + message.color(:green)

  "Well done!"
end

def set_game(new_game)
  @game = new_game
end

def room
  @game.room
end

def hero
  @game.player
end

def wizard
  if @game.character.is_a? Wizard
    @game.character
  else
    print_error "There is no wizard in this room."
  end
end

def scroll
  if @game.player.scroll
    @game.player.scroll
  else
    print_error @game.player.name + ' does not currently have a scroll.'
  end
end

def door
  if @game.room.door
    @game.room.door
  else
    print_error "There is no door in this room."
  end
end

def print_hero
  hero.name.color(:green)
end

# -----||-----------------------------------
#      ||    OBJECTS
# =====||===================================

class GameEntity
  attr_accessor :hidden_methods

  def initialize
    @hidden_methods = [:hidden_methods, :hidden_methods=, :to_s]
  end

  def methods
    list = self.class.instance_methods(false) - @hidden_methods
    list.collect! do |method|
      method.to_s
    end

    say "\nAvailable actions:".color(:yellow)
    list
  end

  def to_s
    "It's a #{self.class.to_s.downcase}."
  end

  def inspect
    to_s
  end

  def method_missing(method, *args)
    print_error "This object does not recognize the message #{method}."
  end
end

class Player < GameEntity
  attr_accessor :items, :game, :hidden_methods
  attr_writer :name

  def initialize(game = nil)
    @items = {}
    @name = nil
    @game = game
    @hidden_methods = [:hidden_methods, :hidden_methods=, :to_s, :items,
      :items=, :game, :game=, :name, :name=, :level, :advance_level,
      :has_name?, :scroll]
  end

  def take(item_name=nil)
    if item_name.nil?
      print_error "You must specify what you want to take."
    else
      item = game.room.items.delete(item_name.to_sym)

      if item
        @items.merge!({item_name.to_sym => item})
        say "\n" + name + " adds " + item.to_s.color(:blue) + " to the loot bag.\n"
        loot
      else
        print_error "There is no " + item_name.to_s.color(:blue) + " in this room.".color(:red)
      end
    end
  end

  def loot
    list = if @items.keys.any?
      @items.keys.collect do |item|
        item.to_s
      end
    else
      []
    end

    say "\nCurrent loot:".color(:blue)
    list
  end

  def scroll
    @items[:scroll]
  end

  def has_name?
    @name
  end

  def name
    @name ? @name : "Our intrepid hero"
  end

  def to_s
    if has_name?
      "Our intrepid hero, #{@name}."
    else
      "Our intrepid hero."
    end
  end
end

class Room < GameEntity
  attr_accessor :items, :door

  def initialize(door = nil, items = {})
    @door = door
    @items = items
    @hidden_methods = [:hidden_methods, :hidden_methods=, :items, :items=, :door, :door=]
  end

  def search
    list = if @items.keys.any?
      @items.keys.collect do |item|
        item.to_s
      end
    else
      []
    end

    say "\nItems in room:".color(:blue)
    list
  end
end

class Door < GameEntity
  def initialize(locked = true, game = nil, blocker = nil)
    @locked = locked
    @game = game
    @blocker = blocker
    @hidden_methods = [:hidden_methods, :hidden_methods=, :to_s]
  end

  def blocked?
    @blocker
  end

  def open
    key = @game.player.items[:key]

    if @locked
      if key.nil?
        print_error "You need a " + "key".color(:blue) + " to open this door.".color(:red)
      else
        if key.door == self
          print_success "Congratulations, the hero has escaped!"
          @game.advance_level
        else
          print_error "This is not the correct key for this door."
        end
      end
    elsif blocked?
      if @game.player.scroll.respond_to?(:cast_spell)
        print_success "The ghoul has been defeated!"
        @game.advance_level
      else
        print_error "There is #{@blocker} blocking this door."
      end
    else
      print_success "The hero leaves the room."
      @game.advance_level
    end
  end

  def to_s
    status = if @locked
      "locked"
    elsif blocked?
      "blocked by #{@blocker}"
    else
      "unlocked"
    end

    "It's a door. It appears to be #{status}."
  end
end

class Key < GameEntity
  attr_accessor :door

  def initialize(door)
    @door = door
  end

  def to_s
    "key"
  end
end

class Scroll < GameEntity
  def to_s
    "scroll"
  end
end

class Character < GameEntity
  def initialize(game = nil)
    @game = game
    @hidden_methods = [:hidden_methods, :hidden_methods=, :to_s]
  end
end

class Ghoul < Character
  def to_s
    'a ghoul'
  end
end

class Wizard < Character
  def to_s
    'A young wizard.'
  end

  def speak
    if @game.player.has_name?
      response = "\"Excellent!\" cries the " + "wizard".color(:blue) + '. "We\'ve been expecting you. The land of Rubinia '.color(:green) +
      'is in frightful shape at the moment, I\'m afraid."'.color(:green)
      response += "\n \n\"You'll need to escape from this dungeon in order to ".color(:green) +
      'begin your hero\'s journey. But remember: It\'s dangerous to go '.color(:green) +
      'alone! Take this."'.color(:green)
      response += "\n \nWith that, the ".color(:green) + 'wizard'.color(:blue) + ' produces a '.color(:green) + 'magical scroll'.color(:blue) +
      ' from under his robe and hands it to '.color(:green) + @game.player.name.color(:green) + '.'
      response += "\n \nIn a flash, a door appears on the opposite wall.".color(:green)

      @game.room.door = Door.new(false, @game)
      @game.player.items.merge!({:scroll => Scroll.new})

      print_success response
    else
      print_error 'The ' + 'wizard'.color(:blue) + ' looks perturbed. "I\'m afraid I cannot allow you to leave until I know your name," he replies.'.color(:red)
    end
  end
end

# -----||-----------------------------------
#      ||    GAME
# =====||===================================

class Game
  attr_accessor :player, :door, :room, :level, :character

  def initialize
    @level = 1
    level_1
  end

  def print_scroll(message)
    say "-----" + "||".color(:red) + "-----------------------------------"
    say "     " + "||        #{message.upcase}".color(:red)
    say "=====" + "||".color(:red) + "==================================="
  end

  def advance_level
    @level += 1
    self.send "level_" + @level.to_s
  end

  # LEVELS

  def level_1
    @player = Player.new(self)
    @door = Door.new(true, self)
    @room = Room.new(@door, {:key => Key.new(@door)})

    say "\n \n"
    print_scroll "the ruby scrolls"

    say "\n \nWelcome to the magical realm of Rubinia!".color(:red)

    say "\nOur intrepid " + "hero".color(:green) + " awakens inside of a small, dimly lit " + "room".color(:blue) + ". There is a " + "door".color(:blue) + " on the far side."
  end

  def level_2
    @room = Room.new(nil)
    @character = Wizard.new(self)

    say "\n \n"
    print_scroll "part 2: the winsome wizard"

    say "\nEmerging into the next room, our " + "hero".color(:green) + " encounters a young " + "wizard".color(:blue) + ", sharply dressed in a purple, silken robe.\n \n"

    say "\n'Come no further,' commands the " + "wizard".color(:blue) + ", with an outstretched hand. 'First I must know your name.'\n\n"

    # Reveal the name setting methods.
    @player.hidden_methods = @player.hidden_methods - [:name, :name=]

    "What to do?"
  end

  def level_3
    @character = Ghoul.new
    @door = Door.new(false, self, @character)
    @room = Room.new(@door)

    say "\n \n"

    print_scroll "part 3: the devilish ghoul"

    say "\nWalking through the ethereal door, " + @player.name.color(:green) + " almost leaps back with terror."

    say "\nJust after passing through, a most frightful ghoul emerges from the darkness. Behind, the door disappears. The " + "door".color(:blue) + " on the far wall is blocked by the hideous ghoul."

    say "\n'Perhaps there's a way to use this " + "scroll".color(:blue) + "...' thinks " + @player.name.color(:green) + "."

    @player.hidden_methods = @player.hidden_methods - [:cast_spell]

    "Cast a spell, " + @player.name + "!"
  end

  def level_4
    say "\n \n"

    print_scroll "CONGRATULATIONS, #{@player.name}"

    print_success "\nOur hero has defeated the ghoul and escaped the dungeon. There is more to be learned and rectified in this magical kingdom. This hero's journey is just beginning..."
  end
end

def cheat_level_1
  hero.take 'key'
  door.open
end

def cheat_level_2
  cheat_level_1
  hero.name = 'Random'
  wizard.speak
  door.open
end

# -----||-----------------------------------
#      ||    GAMEPLAY
# =====||===================================

set_game Game.new