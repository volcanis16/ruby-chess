require "yaml"

COORD_CONVERSION = ["a", "b", "c", "d", "e", "f", "g", "h"]
OPTIONS = ["queen", "rook", "bishop", "knight"]

class BoardSquare
attr_accessor :content
attr_reader :y_coord, :x_coord, :neighboring_square

  def initialize(coord)
    @x_coord = coord[0]
    @y_coord = coord[1]
    neighbors()
    @content = " "
  end

  private

  def neighbors
    @neighboring_square = { nw: [x_coord - 1, y_coord + 1],
                            n:  [x_coord, y_coord + 1],
                            ne: [x_coord + 1, y_coord + 1],
                            e:  [x_coord + 1, y_coord],
                            se: [x_coord + 1, y_coord - 1],
                            s:  [x_coord, y_coord - 1],
                            sw: [x_coord - 1, y_coord - 1],
                            w:  [x_coord - 1, y_coord] }

    @neighboring_square.delete_if {|_, value| value.any? {|coord| coord > 8 || coord < 1 } } #Removes out of bounds values
    @neighboring_square.each {|key, value| @neighboring_square[key] = value.join.to_sym }    #Symbols are easier to use later
  end
end

class Piece
  attr_accessor :x_coord, :y_coord, :board_node, :move_type, :symbol
  attr_reader :piece_type, :player

  SYMBOLS = { black_pawn: "\u2659", black_knight: "\u2658", black_bishop: "\u2657", black_rook: "\u2656",
              black_queen: "\u2655", black_king: "\u2654", white_pawn: "\u265f", white_knight: "\u265e",
              white_bishop: "\u265d", white_rook: "\u265c", white_queen: "\u265b", white_king: "\u265a" }

  def initialize(coord, piece_type, player, board)
    @x_coord = coord[0]
    @y_coord = coord[1]
    @player = player
    @piece_type = piece_type
    @symbol = SYMBOLS[:"#{@player}_#{@piece_type}"]
    @board_node = board[:"#{@x_coord}#{@y_coord}"]
    @board_node.content = self
    moves(@piece_type)
  end

  private

  def moves(piece)
    case piece
    when "pawn"
      if @player == "white"
        @move_type = [:n, :ne, :nw, :first]
      else
        @move_type = [:s, :se, :sw, :first]
      end
    when "bishop"
      @move_type = [:ne, :nw, :sw, :se]
    when "rook"
      @move_type = [:w, :n, :e, :s, :first]
    when "queen"
      @move_type = [:ne, :nw, :sw, :se, :w, :n, :e, :s]
    when "knight"
      @move_type = ["knight"]
    when "king"
      @move_type = [:first]
    end
  end
end

class NewGame
  attr_accessor :player, :player_pieces, :board, :en_passant
  attr_reader :board_class, :move, :validator

  def initialize
    @player = ["white", "black"]  #player and player_pieces are in arrays so they can be easily reversed.
    @board_class = Board.new
    @board = @board_class.board
    @player_pieces = [@board_class.white_pieces, @board_class.black_pieces]
    @en_passant = {pawns: []}     #initialized here because of a check that comes later.
    @move = Move.new(@board_class, @player_pieces, @en_passant) #en_passant passed through to validator
    @validator = @move.validator
  end

  def new_game
    game_over = false

    puts "Would you like to load a previously saved game? y/n"
    load_game() if gets.chomp.downcase() == "y"

    until game_over
      game_over = turn()
    end

    @board_class.print_board()
  end

  def turn
    @en_passant[:used] = false  #:used reset here in case of invalid move choice that makes :used true.

    move_coords = @move.move_start(@player[0])

    target_node = @board[move_coords[1].join.to_sym]
    current_node = @board[move_coords[0].join.to_sym]
    piece = current_node.content
    hold_target = target_node.content   #hold target for undoing moves found to be invalid

    @board_class.update_piece_loc(current_node, target_node, piece)

    @player_pieces[1].delete(hold_target) if hold_target != " "
    
    castle_safe = @move.castling(target_node) if @validator.castle[:used]  #only checks for the rook being threatened as the king has already been tested
    if castle_safe == false   
      @board_class.update_piece_loc(target_node, current_node, piece)
      puts "Castling here leaves the rook or king in a threatened square. Please try another move."
      return turn()
    end

    if @en_passant[:used]
      hold_node = @en_passant[:target].board_node
      @en_passant[:target].board_node.content = " "
      @player_pieces[1].delete(@en_passant[:target])
    end

    if @validator.check_for_threat(@player_pieces[1], @player_pieces[0]) != nil
      puts "That move leaves you in check try another."

      @board_class.update_piece_loc(target_node, current_node, piece)
      target_node.content = hold_target
      @player_pieces[1] << hold_target if hold_target != " "

      if @en_passant[:used]
        @player_pieces[1] << @en_passant[:target]
        hold_node.content = @en_passant[:target]
      end

      return turn()
    end

    if piece.piece_type == "pawn" && ((@player[0] == "white" && piece.y_coord == 8) ||
                                      (@player[0] == "black" && piece.y_coord == 1))
      @board_class.promotion(target_node, piece, @player_pieces[0], @player[0])
    end

    check_piece = @validator.check_for_threat(@player_pieces[0], @player_pieces[1])
    if check_piece
        checkmate = @validator.checkmate?(@player_pieces[1], check_piece,)
      if checkmate
        puts "Checkmate. #{@player[0].capitalize} wins."
        return true
      else
        puts "#{@player[1].capitalize}, you are in check."
      end
    end
    
    turn_cleanup(piece)
    @en_passant[:pawns] = []
    en_passant_set(target_node) if piece.piece_type == "pawn" && (current_node.y_coord - target_node.y_coord).abs > 1

    false
  end

  def load_game
    save_data = []
    file = File.open("save_file.yaml", "r")
    save_data << YAML::load(file)

    w_pieces = save_data[0][1].split("/")
    b_pieces = save_data[0][2].split("/")
    passant = save_data[0][3].split("/")

    blank_board()
    
    w_pieces.each do |piece|
      piece = piece.split(", ")
      @board_class.white_pieces << Piece.new([piece[0].to_i, piece[1].to_i], piece[2], "white", @board)
      @board[:"#{piece[0]}#{piece[1]}"].content.move_type.delete(:first) if piece[3] != "first"
    end

    b_pieces.each do |pi|
      pi = pi.split(", ")
      @board_class.black_pieces << Piece.new([pi[0].to_i, pi[1].to_i], pi[2], "black", @board)
      @board[:"#{pi[0]}#{pi[1]}"].content.move_type.delete(:first) if pi[3] != "first"
    end

    if save_data[0][0] == "white"
      @player = ["white", "black"]
      @player_pieces = [@board_class.white_pieces, @board_class.black_pieces]
      @move.player_pieces = @player_pieces
      @validator.player_pieces = @player_pieces
    else 
      @player = ["black", "white"]
      @player_pieces = [@board_class.black_pieces, @board_class.white_pieces]
      @move.player_pieces = @player_pieces
      @validator.player_pieces = @player_pieces
    end

    passant.each do |pair|
      pair = pair.split(", ")

      if pair[0] == "pawns" && !pair[1].nil?
        pair[1] = pair[1].split("_")
        pair[1].each { |piece| @en_passant[:pawns] << @board[:"#{piece}"].content }
      end

      @en_passant[:target] = @board[:"#{pair[1]}"].content if pair[0] == "target"
    end

  end
  
  private

  def turn_cleanup(piece)
    piece.move_type.delete(:first)

    @player.reverse!
    @player_pieces.reverse!
  end

  def blank_board
    @board.each { |_, square| square.content = " " }
    @board_class.white_pieces = []
    @board_class.black_pieces = []
    @player_pieces = [@board_class.white_pieces, @board_class.black_pieces]
    @move.player_pieces = @player_pieces
    @validator.player_pieces = @player_pieces
  end

  def en_passant_set(pawn_node)
    @en_passant[:target] = pawn_node.content
    neighbors = [@board[pawn_node.neighboring_square[:e]], @board[pawn_node.neighboring_square[:w]]]
    neighbors.delete_if {|node| node == nil || node.content == " " || node.content.piece_type != "pawn"}
    neighbors.each {|node| @en_passant[:pawns] << node.content}
  end
end

class Move
  attr_accessor :player_pieces
  attr_reader :move, :validator
  
  def initialize(board_class, pieces, en_passant)
    @board_class = board_class
    @board = board_class.board
    @player_pieces = pieces
    @validator = Validator.new(@board_class, @player_pieces, en_passant)
  end

  def move_start(player)
    @player = player
    valid = false
    first_try = true
    move = []

    until valid do
      puts "That move is not valid try another." if first_try == false
      first_try = false

      @board_class.print_board()

      puts "#{player.capitalize}, what piece would you like to move? e.g. 'a1'\nType 'save' to save"
      move[0] = move()

      unless @player_pieces[0].include?(@board[move[0].join.to_sym].content)
        puts "That square does not hold one of your pieces."
        first_try = true
        redo
      end

      puts "Where would you like to move it to?"
      move[1] = move()

      valid = @validator.valid_move?(move)
    end

    move
  end

  def castling(king_square)
    starting_node = @validator.castle[:rook].board_node
    @validator.castle[:used] = false

    if starting_node.x_coord < king_square.x_coord
      target_node = @board[king_square.neighboring_square[:e]]
    else
      target_node = @board[king_square.neighboring_square[:w]]
    end

    @board_class.update_piece_loc(starting_node, target_node, @validator.castle[:rook])

    if @validator.check_for_threat(@player_pieces[1], @player_pieces[0], target_node) ||
       @validator.check_for_threat(@player_pieces[1], @player_pieces[0])
    then
      @board_class.update_piece_loc(target_node, starting_node, @validator.castle[:rook])
      return false
    else
      true
    end
  end

  private

  def move
    valid = false

    until valid do
      move = gets.chomp.downcase
      if move.match(/^[a-h][1-8]$/)
        valid = true
      elsif move == "save"
        save_game()
        puts "Game Saved. Keep playing."
      else
        puts "That is not a valid input. Please try again."
      end
    end

    move = move.split(//)
    move[0] = COORD_CONVERSION.find_index(move[0]) + 1
    move[1] = move[1].to_i
    move
  end

  def save_game
    w_pieces = []
    b_pieces = []

    w_pieces = piece_serialize(@board_class.white_pieces)
    b_pieces = piece_serialize(@board_class.black_pieces)

    passant = []
    @validator.en_passant.each do |key, value|
      next if key == :used
      if key == :pawns
        values = []
        value.each { |v| values << [v.x_coord, v.y_coord].join() }
        values = values.join("_")
        passant << [key, values].join(", ")
      else
        passant << [key, "#{value.x_coord}#{value.y_coord}"].join(", ")
      end
    end

    File.open("save_file.yaml", "w") do |file|
      file.puts YAML::dump([
        @player,
        w_pieces.join("/"),
        b_pieces.join("/"),
        passant.join("/")]
      )
    end
  end

  def piece_serialize(pieces)
    piece_set = []
    pieces.each do |p|
      hold = [p.x_coord, p.y_coord, p.piece_type]
      hold << "first" if p.move_type.include?(:first)
      piece_set << hold.join(", ")
    end

    piece_set
  end

end

class Validator
  attr_accessor :en_passant, :castle, :player_pieces

  def initialize(board_class, pieces, en_passant)
    @board_class = board_class
    @board = board_class.board
    @player_pieces = pieces
    @en_passant = en_passant
    @castle = Hash.new
  end

  def valid_move?(move)
    target_node = @board[move[1].join.to_sym]
    current_node = @board[move[0].join.to_sym]
    piece = current_node.content
    return false if target_node.content != " " && target_node.content.player == current_node.content.player #don't target your own piece

    return knight_move?(current_node, target_node) if piece.piece_type == "knight"

    direction = move_direction(move)
    return false if direction == false

    return king_move?(current_node, target_node, piece, direction) if piece.piece_type == "king"

    return false if !piece.move_type.include?(direction) #don't move in a direction your piece cant

    return pawn_move?(current_node, target_node, piece, direction) if piece.piece_type == "pawn"
    return path_check?(current_node, target_node, piece, direction) #for rooks queens and bishops
  end

  def check_for_threat(player_pieces, enemy_pieces, target_node = " ")
    target_node = find_king(enemy_pieces) if target_node == " "

    player_pieces.each do |piece|
      return piece if valid_move?([[piece.x_coord, piece.y_coord], [target_node.x_coord, target_node.y_coord]])
    end
    nil
  end

  def checkmate?(enemy_pieces, check_piece)
    target_node = find_king(enemy_pieces).board_node

    return false if king_move_safe?(target_node)

    if check_piece.piece_type == "knight" #Only way to stop a knight other than moving the king is to kill it.
      return enemy_pieces.none? do |piece|
        valid_move?([[piece.x_coord, piece.y_coord], [check_piece.x_coord, check_piece.y_coord]])
      end
    end

    direction = move_direction([[check_piece.x_coord, check_piece.y_coord], [target_node.x_coord, target_node.y_coord]])
    current_node = check_piece.board_node
    target_squares = []

    until current_node == target_node do #puts all of the squares between the king and the threat into an array
      target_squares << current_node
      current_node = @board[current_node.neighboring_square[direction]]
    end

    enemy_pieces.each do |piece|
      return false if move_in_set_valid?(target_squares, piece)
    end

    true
  end

  private

  def find_king(pieces)
    index = pieces.find_index {|ele| ele.piece_type == "king"}
    pieces[index]
  end

  def king_move_safe?(king_node)
    king_moves = []
    king_node.neighboring_square.each_value do |value| 
      king_moves << @board[value]
    end

    return move_in_set_valid?(king_moves, king_node.content)
  end

  def move_in_set_valid?(target_squares, piece)
    valid = false
    target_squares.each do |square|
      if valid_move?([[piece.x_coord, piece.y_coord], [square.x_coord, square.y_coord]])
        hold_target = square.content
        starting_node = piece.board_node
        @board_class.update_piece_loc(starting_node, square, piece)

        if check_for_threat(@player_pieces[0], @player_pieces[1]) != nil
          valid = false
        else
          valid = true
        end

        @board_class.update_piece_loc(square, starting_node, piece)
        square.content = hold_target
        break if valid == true
      end
    end
    valid
  end

  def move_direction(move)
    case
    when move[0][1] < move[1][1]
      case
      when move[0][0] < move[1][0]
        direction = :ne
      when move[0][0] > move[1][0]
        direction = :nw
      else
        direction = :n
      end
    when move[0][1] > move[1][1]
      case
      when move[0][0] < move[1][0]
        direction = :se
      when move[0][0] > move[1][0]
        direction = :sw
      else
        direction = :s
      end
    else
      case
      when move[0][0] < move[1][0]
        direction = :e
      when move[0][0] > move[1][0]
        direction = :w
      else
        return false #this happens when the starting and target squares are the same.
      end
    end

    #vvvvv Tests to make sure diagonals are on straight lines
    if [:se, :sw, :ne, :nw].include?(direction) && (move[0][0] - move[1][0]).abs != (move[0][1] - move[1][1]).abs
      false
    else
      direction
    end
  end
  
  def king_move?(current_node, target_node, piece, direction)
    @castle = Hash.new
    double_move = false

    if (current_node.x_coord - target_node.x_coord).abs > 2 || (current_node.y_coord - target_node.y_coord).abs > 2
      return false
    elsif (current_node.x_coord - target_node.x_coord).abs == 2 || (current_node.y_coord - target_node.y_coord).abs == 2
      double_move = true
    else
      return true
    end

    return false if double_move && (!piece.move_type.include?(:first) || ![:e, :w].include?(direction))

    direction == :w ? corner = [1, piece.y_coord].join.to_sym : corner = [8, piece.y_coord].join.to_sym

    return false if @board[corner].content == " " || @board[corner].content.piece_type != "rook"
    return false unless @board[corner].content.move_type.include?(:first)
    return false unless path_check?(current_node, @board[corner], piece, direction) #checks to make sure the squares between the king and rook are empty

    @castle[:rook] = @board[corner].content
    @castle[:used] = true

    true
  end

  def knight_move?(current_node, target_node)
    possible_moves = [[current_node.x_coord + 2, current_node.y_coord + 1],
    [current_node.x_coord + 2, current_node.y_coord - 1],
    [current_node.x_coord + 1, current_node.y_coord + 2],
    [current_node.x_coord - 1, current_node.y_coord + 2],
    [current_node.x_coord - 2, current_node.y_coord + 1],
    [current_node.x_coord - 2, current_node.y_coord - 1],
    [current_node.x_coord - 1, current_node.y_coord - 2],
    [current_node.x_coord + 1, current_node.y_coord - 2]]

    return true if possible_moves.include?([target_node.x_coord, target_node.y_coord])

    false
  end
  
  def pawn_move?(current_node, target_node, piece, direction)
    return false if (current_node.y_coord - target_node.y_coord).abs > 2

    if (current_node.y_coord - target_node.y_coord).abs == 2
      return false unless [:n, :s].include?(direction) && target_node.content == " "
      return false unless piece.move_type.include?(:first)
      return path_check?(current_node, target_node, piece, direction)
    end

    return true if [:n, :s].include?(direction) && target_node.content == " "

    if [:nw, :ne, :se, :sw].include?(direction)
      return true if target_node.content != " "

      if @en_passant[:pawns].include?(piece) && target_node.x_coord == @en_passant[:target].x_coord
        @en_passant[:used] = true
        return true 
      end
    end

    false
  end

  def path_check?(current_node, target_node, piece, direction)
    until current_node == target_node
      return false if current_node == nil || (current_node.content != piece && current_node.content != " ")
      current_node = @board[current_node.neighboring_square[direction]]
    end
    true
  end
end

class Board
  attr_accessor :board, :white_pieces, :black_pieces

  def initialize
    new_board()
    initial_pieces()
  end

  def update_piece_loc(current_node, target_node, piece)
    piece.x_coord = target_node.x_coord
    piece.y_coord = target_node.y_coord
    piece.board_node = target_node
    target_node.content = piece
    current_node.content = " "
  end

  def promotion(node, piece, pieces, player)
    choice = promotion_choice()

    pieces << Piece.new([node.x_coord, node.y_coord], choice, player, @board)
    pieces.delete(piece)
  end

  def print_board
    line = ""
    puts ""
    puts " \e[4m|a|b|c|d|e|f|g|h|"
    8.times do |y|
      line = ""
      print "\e[0m#{8 - y}"
      print "\e[4m"
      8.times do |x|
        square = @board[:"#{x + 1}#{8 - y}"]
        if square.content == " "
          line << "| "
        else
          line << "|#{square.content.symbol}"
        end
      end
      print line
      puts "\e[0m|#{8 - y}"
    end
    puts " |a|b|c|d|e|f|g|h|"
  end

  private

  def initial_pieces
    @white_pieces = []
    @black_pieces = []
    pawns()
    knights()
    bishops()
    rooks()
    kings_queens()
  end

  def promotion_choice
    puts "Promotion! What would you like your pawn to become?"

    valid = false
    until valid do
      choice = gets.chomp.downcase
      if OPTIONS.include?(choice)
        valid = true
      else
        puts "Thats not an option. Try again."
      end
    end

    choice
  end

  def new_board
    @board = {}
    8.times do |time|
      x = time + 1
      8.times do |y|
        y = y + 1
        @board[:"#{x}#{y}"] = BoardSquare.new([x,y])
      end
    end
  end

  def pawns
    8.times do |time|
      @white_pieces << Piece.new([time + 1, 2], "pawn", "white", @board)
    end

    8.times do |time|
      @black_pieces << Piece.new([time + 1, 7], "pawn", "black", @board)
    end
  end

  def knights
    @white_pieces << Piece.new([2, 1], "knight", "white", @board) << Piece.new([7, 1], "knight", "white", @board)
    @black_pieces << Piece.new([2, 8], "knight", "black", @board) << Piece.new([7, 8], "knight", "black", @board)
  end

  def bishops
    @white_pieces << Piece.new([3, 1], "bishop", "white", @board) << Piece.new([6, 1], "bishop", "white", @board)
    @black_pieces << Piece.new([3, 8], "bishop", "black", @board) << Piece.new([6, 8], "bishop", "black", @board)
  end

  def rooks
    @white_pieces << Piece.new([1, 1], "rook", "white", @board) << Piece.new([8, 1], "rook", "white", @board)
    @black_pieces << Piece.new([1, 8], "rook", "black", @board) << Piece.new([8, 8], "rook", "black", @board)
  end

  def kings_queens
    @white_pieces << Piece.new([5, 1], "king", "white", @board) << Piece.new([4, 1], "queen", "white", @board)
    @black_pieces << Piece.new([5, 8], "king", "black", @board) << Piece.new([4, 8], "queen", "black", @board)
  end
end

@game = NewGame.new
@game.new_game()
