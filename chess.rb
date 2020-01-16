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
                            se: [x_coord - 1, y_coord + 1],
                            s:  [x_coord, y_coord - 1],
                            sw: [x_coord - 1, y_coord],
                            w:  [x_coord - 1, y_coord - 1] }

    @neighboring_square.delete_if {|_, value| value.any? {|coord| coord > 8 || coord < 1 } }
    @neighboring_square.each_value {|value| value.join.to_sym }
  end
end

class Piece
  attr_accessor :x_coord, :y_coord, :board_square, :move_type, :symbol
  attr_reader :piece_type, :player

  SYMBOLS = { black_pawn: "\u2659", black_knight: "\u2658", black_bishop: "\u2657", black_rook: "\u2656",
              black_queen: "\u2655", black_king: "\u2654", white_pawn: "\u265f", white_knight: "\u265e",
              white_bishop: "\u265d", white_rook: "\u265c", white_queen: "\u265b", white_king: "\u265a" }

  def initialize(coord, piece_type, player, board)
    @x_coord = coord[0]
    @y_coord = coord[1]
    @player = player
    @piece_type = piece_type
    @symbol = SYMBOLS["#{@player}_#{@piece_type}".to_sym]
    @board_node = board["#{@x_coord}#{@y_coord}".to_sym]
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
  attr_accessor :player, :player_pieces, :board

  def initialize
    @player = ["white", "black"]
    new_board()
    initial_pieces()
    @player_pieces = [@white_pieces, @black_pieces]
    @en_passant = Hash.new
    @castle = Hash.new
  end

  def new_game
    turn()
  end

  private

  def turn
    valid = false
    first_try = true
    move = []

    until valid do
      puts "That move is not valid try another." if first_try == false
      first_try = false

      puts "#{@player[0].capitalize}, what piece would you like to move? e.g. 'a1'"
      move[0] = move()

      puts "Where would you like to move it to?"
      move[1] = move()

      valid = valid_move?(move)
    end

    target_node = @board[move[1].join.to_sym]
    current_node = @board[move[0].join.to_sym]
    piece = current_node.content
    hold_target = target_node.content

    update_piece_loc(current_node, target_node, piece)

    castle_safe = castle(target_node) if @castle[:used]
    if castle_safe == false
      update_piece_loc(target_node, current_node, piece)
      puts "Castling here leaves the rook or king in a threatened square. Please try another move."
      turn()
    end

    @en_passant[:target].board_node.content = " " if @en_passant[:used]

    if check_for_threat(@player_pieces[1], @player_pieces[0]) != nil
      puts "That move leaves you in check try another."
      update_piece_loc(target_node, current_node, piece)
      target_node.content = hold_target
      @en_passant[:target].board_node.content = @en_passant[:target] if @en_passant[:used]
      turn()
    end

    @player_pieces[1].delete(target_node.content) if target_node.content != " "
    @player_pieces[1].delete(@en_passant[:target]) if @en_passant[:used]
    
    if piece.piece_type == "pawn" && ((@player[0] == "white" && piece.y_coord == 8) ||
                                      (@player[0] == "black" && piece.y_coord == 1))
      promotion(target_node, piece)
    end

    check_piece = check_for_threat(@player_pieces[0], @player_pieces[1])
    if check_piece
        checkmate = checkmate?(@player_pieces[1], check_piece)
      if checkmate
        puts "Checkmate. #{@player[0].capitalize} wins."
        exit!
      else
        puts "#{@player[1].capitalize}, you are in check."
      end
    end


    turn_cleanup(piece)
    @en_passant = Hash.new
    en_passant_set(target_node) if piece.piece_type == "pawn" && (current_node.y_coord - target_node.y_coord).abs > 1
    turn()
  end

  def turn_cleanup(piece)
    piece.move_type.delete(:first)

    @player.reverse!
    @player_pieces.reverse!
  end

  def move
    valid = false

    until valid do
      print_board()
      move = gets.chomp.downcase
      if move.match(/^[a-h][1-8]$/)
        valid = true
      else
        puts "That is not a valid input. Please try again."
      end
    end

    move = move.split(//)
    move[0] = COORD_CONVERSION.find_index(move[0]) + 1
    move[1] = move[1].to_i
    move
  end

  def valid_move?(move)
    target_node = @board[move[1].join.to_sym]
    current_node = @board[move[0].join.to_sym]
    piece = current_node.content
    return false unless target_node.content == " " || target_node.content.player == @player[1]

    return knight_move?(current_node, target_node) if piece.piece_type == "knight"

    direction = move_direction(move)
    return false if direction == false

    return king_move?(current_node, target_node, piece, direction) if piece.piece_type == "king"

    return false if !piece.move_type.include?(direction)

    return pawn_move?(current_node, target_node, piece, direction) if piece.piece_type == "pawn"
    return path_check(current_node, target_node, piece, direction)
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
        return false
      end
    end
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
    elsif (current_node.x_coord - target_node.x_coord).abs = 2 || (current_node.y_coord - target_node.y_coord).abs = 2
      double_move = true
    else
      return true
    end

    return false if double_move && (!piece.move_type.include?(:first) || ![:e, :w].include?(direction))

    direction == :w ? corner = [1, piece.y_coord].join.to_sym : corner = [8, piece.y_coord].join.to_sym

    return false if @board[corner].content != "rook"
    return false unless @board[corner].content.move_type.include?(:first)
    return false unless path_check(current_node, @board[corner], piece, direction)

    @castle[:rook] = @board[corner].content
    @castle[:used] = true

    true
  end

  def castle(king_square)
    starting_node = @castle[:rook].board_node
    @castle[:used] = false

    if starting_position.x_coord < king_square.x_coord
      target_node = @board[king_square.neighboring_square[:e]]
    else
      target_node = @board[king_square.neighboring_square[:w]]
    end

    update_piece_loc(starting_node, target_node, @castle[:rook])

    if check_for_threat(@player_pieces[1], @player_pieces[0], @castle[:rook]) ||
       check_for_threat(@player_pieces[1], @player_pieces[0])
    then
      update_piece_loc(target_node, starting_node, @castle[:rook])
      return false
    else
      true
    end
  end

  def knight_move?(current_node, target_node)
    possible_moves = [[current_node.x_coord + 2, current_node.y_coord + 1],
    [current_node.x_coord + 2, current_node.y_coord + 1],
    [current_node.x_coord + 1, current_node.y_coord + 2],
    [current_node.x_coord - 1, current_node.y_coord + 2],
    [current_node.x_coord - 2, current_node.y_coord + 1],
    [current_node.x_coord - 2, current_node.y_coord - 1],
    [current_node.x_coord - 1, current_node.y_coord - 2],
    [current_node.x_coord + 1, current_node.y_coord - 2]]

    return true if possible_moves.include?([target_node.x_coord, target_node.y_coord]) && target_node.content == " "

    false
  end
  
  def pawn_move?(current_node, target_node, piece, direction)
    if (current_node.y_coord - target_node.y_coord).abs > 1
      return false if piece.move_type.include?(:first)
      return path_check(current_node, target_node, piece, direction)
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

  def path_check(current_node, target_node, piece, direction)
    until current_node == target_node
      return false if current_node == nil || current_node.content != piece || current_node.content != " "
      current_node = @board[current_node.neighboring_square[direction]]
    end
    true
  end

  def find_king(pieces)
    index = pieces.find_index {|ele| ele.piece_type == "king"}
    pieces[index]
  end

  def check_for_threat(player_pieces, enemy_pieces, target_node = " ")
    target_node = find_king(enemy_pieces) if target_node == " "

    player_pieces.each do |piece|
      return piece if valid_move?([[piece.x_coord, piece.y_coord], [target_node.x_coord, target_node.y_coord]])
    end
    nil
  end

  def checkmate?(enemy_pieces, check_piece)
    if check_piece.piece_type == "knight"
      return enemy_pieces.none? do |piece|
        valid_move?([[piece.x_coord, piece.y_coord], [check_piece.x_coord, check_piece.y_coord]])
      end
    end

    target_node = find_king(enemy_pieces)

    return false if king_move_safe?(target_node)

    direction = move_direction([[check_piece.x_coord, check_piece.y_coord], [target_node.x_coord, target_node.y_coord]])
    current_node = check_piece.board_node
    target_squares = []

    until current_node == target_node do
      target_squares << current_node
      current_node = @board[current_node.neighboring_square[direction]]
    end
      
    enemy_pieces.each do |piece|
      if move_in_set_valid?(target_squares, piece)
        checkmate = false
      else
        checkmate = true
        break
      end
    end

    checkmate
  end

  def king_move_safe?(king_node)
    king_moves = []
    target_node.neighboring_square.each_value do |value| 
      king_moves << @board[value]
    end

    return move_in_set_valid?(king_moves, king_node.content)
  end

  def move_in_set_valid?(target_squares, piece)
    return target_squares.any? do |square|
      if valid_move?([[piece.x_coord, piece.y_coord], [square.x_coord, square.y_coord]])
        hold_target = square.content
        update_piece_loc(piece.board_node, square, piece)

        if check_for_threat(@player_pieces[0], @player_pieces[1]) != nil
          check = false
        else
          check = true
        end

        update_piece_loc(square, piece.board_node, piece)
        square.content = hold_target

        check
      else
        false
      end
    end
  end

  def update_piece_loc(current_node, target_node, piece)
    piece.x_coord = target_node.x_coord
    piece.y_coord = target_node.y_coord
    piece.board_square = target_node
    target_node.content = piece
    current_node.content = " "
  end

  def promotion(node, piece)
    choice = promotion_choice()

    @player_pieces[0] << Piece.new([node.x_coord, node.y_coord], choice, @player[0], @board)
    @player_pieces[0].delete(piece)
  end

  def promotion_choice
    puts "Promotion! What would you like your pawn to become?"

    valid = false
    until valid do
      choice = gets.downcase
      if OPTIONS.include?(choice)
        valid = true
      else
        puts "Thats not an option. Try again."
      end
    end

    choice
  end

  def en_passant_set(pawn_node)
    @en_passant[target: pawn_node.content, pawns: []]
    neighbors = [@board[pawn_node.neighboring_square[:e]], @board[pawn_node.neighboring_square[:w]]]
    neighbors.delete_if {|node| node.content == " " || node.content.piece_type != "pawn"}
    neighbors.each {|node| @en_passant[:pawns] << node.content}
  end

  def print_board
    puts ""
    puts " \e[4m|a|b|c|d|e|f|g|h|"
    8.times do |y|
      print "\e[0m#{8 - y}"
      print "\e[4m"
      8.times do |x|
        square = @board["#{x + 1}#{8 - y}".to_sym]
        if square.content == " "
          print "| "
        else
          print "|#{square.content.symbol}"
        end
      end
      puts "\e[0m|#{8 - y}"
    end
    puts " |a|b|c|d|e|f|g|h|"
  end

  def new_board
    @board = {}
    8.times do |time|
      x = time + 1
      8.times do |y|
        y = y + 1
        @board["#{x}#{y}".to_sym] = BoardSquare.new([x,y])
      end
    end
  end

  def initial_pieces
    @white_pieces = []
    @black_pieces = []
    pawns()
    knights()
    bishops()
    rooks()
    kings_queens()
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