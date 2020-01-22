require '../chess'

describe Board do
  before(:each) { @board = Board.new }

  it "Has an initial board." do
    expect { @board.board.all {|_, value| value.class == BoardSquare} }
    expect { @board.board.all {|_, value| value.content.class == Piece} }
  end

  it "Prints the board." do
    expect { @board.print_board() }.to output("\n \e[4m|a|b|c|d|e|f|g|h|\n" +
                                              "\e[0m8\e[4m|♖|♘|♗|♕|♔|♗|♘|♖\e[0m|8\n" +
                                              "\e[0m7\e[4m|♙|♙|♙|♙|♙|♙|♙|♙\e[0m|7\n" +
                                              "\e[0m6\e[4m| | | | | | | | \e[0m|6\n" +
                                              "\e[0m5\e[4m| | | | | | | | \e[0m|5\n" +
                                              "\e[0m4\e[4m| | | | | | | | \e[0m|4\n" +
                                              "\e[0m3\e[4m| | | | | | | | \e[0m|3\n" +
                                              "\e[0m2\e[4m|♟|♟|♟|♟|♟|♟|♟|♟\e[0m|2\n" +
                                              "\e[0m1\e[4m|♜|♞|♝|♛|♚|♝|♞|♜\e[0m|1\n" +
                                              " |a|b|c|d|e|f|g|h|\n").to_stdout
  end

  it "Moves pieces." do
    piece = @board.board[:"42"].content
    @board.update_piece_loc(@board.board[:"42"], @board.board[:"43"], @board.board[:"42"].content)
    expect(@board.board[:"42"].content).to eql(" ")
    expect(@board.board[:"43"].content).to eql(piece)
    expect(piece.x_coord).to eql(4)
    expect(piece.y_coord).to eql(3)
    expect(piece.board_node).to eql(@board.board[:"43"])
  end

  it "Accepts only valid promotion choice." do
    allow(@board).to receive_message_chain("gets.chomp.downcase").and_return("king", "knight")
    expect do
      @board.promotion(@board.board[:"48"], @board.board[:"42"].content, @board.white_pieces, "white")
    end.to output(/Thats not an option. Try again./).to_stdout
  end

  it "Updates after promotion." do
    allow(@board).to receive_message_chain("gets.chomp.downcase").and_return("knight")

    piece = @board.board[:"42"].content
    @board.promotion(@board.board[:"48"], piece, @board.white_pieces, "white")

    expect(@board.board[:"48"].content.piece_type).to eql("knight")
    expect(@board.white_pieces.include?(piece)).to eql(false)
  end
end

describe Move do
  describe "#move_start" do
    before(:each) do
      @board = Board.new
      @en_passant = {pawns: []}
      @move = Move.new(@board, [@board.white_pieces, @board.black_pieces], @en_passant)
      allow(@move).to receive_message_chain("validator.valid_move?").and_return(true)
    end

    it "Only accepts valid input." do
      allow(@move).to receive_message_chain("gets.chomp.downcase").and_return("a9", "a2", "a4")
      expect { @move.move_start("white") }.to output(/That is not a valid input. Please try again./).to_stdout

      allow(@move).to receive_message_chain("gets.chomp.downcase").and_return("24", "a2", "a4")
      expect { @move.move_start("white") }.to output(/That is not a valid input. Please try again./).to_stdout

      allow(@move).to receive_message_chain("gets.chomp.downcase").and_return("king", "a2", "a4")
      expect { @move.move_start("white") }.to output(/That is not a valid input. Please try again./).to_stdout

      allow(@move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a2", "a4")
      expect { @move.move_start("white") }.to output(/That square does not hold one of your pieces./).to_stdout

      allow(@move).to receive_message_chain("gets.chomp.downcase").and_return("a6", "a2", "a4")
      expect { @move.move_start("white") }.to output(/That square does not hold one of your pieces./).to_stdout
    end
  end

  describe "#castling" do
    before(:each) do
      @board = Board.new 
      @board.board[:"21"].content = " "
      @board.board[:"31"].content = " "
      @board.board[:"41"].content = " "
      @en_passant = {pawns: []}
      @move = Move.new(@board, [@board.white_pieces, @board.black_pieces], @en_passant)
      @move.validator.castle[:rook] = @board.board[:"11"].content
    end

    it "Moves the pieces." do
      allow(@move).to receive_message_chain("validator.check_for_threat").and_return(false)
      @move.castling(@board.board[:"31"])
      expect(@board.board[:"41"].content.piece_type).to eql("rook")
    end

    it "Doesn't move the piece to a threatened square" do
      @board.update_piece_loc(@board.board[:"51"], @board.board[:"31"], @board.board[:"51"].content)
      @board.update_piece_loc(@board.board[:"18"], @board.board[:"42"], @board.board[:"18"].content)
      expect(@move.castling(@board.board[:"31"])).to eql(false)

      @board.update_piece_loc(@board.board[:"42"], @board.board[:"32"], @board.board[:"42"].content)
      expect(@move.castling(@board.board[:"31"])).to eql(false)
    end
  end  
end

describe Validator do
  describe "#valid_move?" do
    before(:each) do
      @board = Board.new
      @en_passant = {pawns: []}
      @validator = Validator.new(@board, [@board.white_pieces, @board.black_pieces], @en_passant)
    end

    it "Returns false if target is own piece." do
      expect(@validator.valid_move?([[1, 1], [1, 2]])).to eql(false)
    end

    it "Uses the right check." do
      expect(@validator).to receive(:path_check?).with(
        @board.board[:"11"],
        @board.board[:"13"],
        @board.board[:"11"].content,
        :n)
      @validator.valid_move?([[1, 1], [1, 3]])

      expect(@validator).to receive(:pawn_move?).with(
        @board.board[:"12"],
        @board.board[:"13"],
        @board.board[:"12"].content,
        :n)
      @validator.valid_move?([[1, 2], [1, 3]])

      expect(@validator).to receive(:king_move?).with(
        @board.board[:"51"],
        @board.board[:"53"],
        @board.board[:"51"].content,
        :n)
      @validator.valid_move?([[5, 1], [5, 3]])

      expect(@validator).to receive(:knight_move?).with(
        @board.board[:"21"],
        @board.board[:"13"])
      @validator.valid_move?([[2, 1], [1, 3]])
    end

    it "Fails if target square is same as starting square." do
      expect(@validator.valid_move?([[1, 1], [1, 1]])).to eql(false)
    end

    it "Tests direction validity." do
      @board.update_piece_loc(@board.board[:"62"], @board.board[:"63"], @board.board[:"62"].content)
      expect(@validator.valid_move?([[6, 3], [6, 2]])).to eql(false)
      expect(@validator.valid_move?([[6, 1], [6, 2]])).to eql(false)

      @board.update_piece_loc(@board.board[:"72"], @board.board[:"73"], @board.board[:"72"].content)
      @board.update_piece_loc(@board.board[:"71"], @board.board[:"75"], @board.board[:"71"].content)

      expect(@validator.valid_move?([[6, 1], [7, 2]])).to eql(true)
      expect(@validator.valid_move?([[8, 1], [7, 2]])).to eql(false)
      expect(@validator.valid_move?([[8, 1], [7, 1]])).to eql(true)
    end

    it "Tests pawn moves." do
      expect(@validator.valid_move?([[1, 2], [1, 3]])).to eql(true)
      expect(@validator.valid_move?([[1, 2], [1, 4]])).to eql(true)
      expect(@validator.valid_move?([[1, 2], [2, 3]])).to eql(false)
      expect(@validator.valid_move?([[1, 2], [6, 7]])).to eql(false)

      @board.update_piece_loc(@board.board[:"27"], @board.board[:"23"], @board.board[:"27"].content)
      expect(@validator.valid_move?([[1, 2], [2, 3]])).to eql(true)

      @board.board[:"12"].content.move_type.delete(:first)
      expect(@validator.valid_move?([[1, 2], [1, 4]])).to eql(false)

      @en_passant[:used] = true
      @en_passant[:target] = @board.board[:"23"].content
      @en_passant[:pawns] << @board.board[:"12"].content
      @board.update_piece_loc(@board.board[:"12"], @board.board[:"13"], @board.board[:"12"].content)
      expect(@validator.valid_move?([[1, 3], [2, 4]])).to eql(true)
    end

    it "Tests king moves." do
      @board.update_piece_loc(@board.board[:"52"], @board.board[:"13"], @board.board[:"52"].content)
      @board.update_piece_loc(@board.board[:"21"], @board.board[:"23"], @board.board[:"21"].content)
      @board.update_piece_loc(@board.board[:"31"], @board.board[:"24"], @board.board[:"31"].content)
      @board.update_piece_loc(@board.board[:"41"], @board.board[:"25"], @board.board[:"41"].content)

      expect(@validator.valid_move?([[5, 1], [5, 4]])).to eql(false)
      expect(@validator.valid_move?([[5, 1], [5, 2]])).to eql(true)
      expect(@validator.valid_move?([[5, 1], [5, 3]])).to eql(false)
      expect(@validator.valid_move?([[5, 1], [3, 1]])).to eql(true)
      expect(@validator.castle[:used]).to eql(true)

      @board.update_piece_loc(@board.board[:"11"], @board.board[:"14"], @board.board[:"11"].content)
      expect(@validator.valid_move?([[5, 1], [3, 1]])).to eql(false)

      @board.update_piece_loc(@board.board[:"14"], @board.board[:"11"], @board.board[:"14"].content)
      @board.board[:"11"].content.move_type.delete(:first)
      expect(@validator.valid_move?([[5, 1], [3, 1]])).to eql(false)

      @board.board[:"11"].content.move_type << :first
      @board.board[:"51"].content.move_type.delete(:first)
      expect(@validator.valid_move?([[5, 1], [3, 1]])).to eql(false)
    end

    it "Tests knight moves." do
      @board.update_piece_loc(@board.board[:"21"], @board.board[:"44"], @board.board[:"21"].content)
      expect(@validator.valid_move?([[4, 4], [5, 6]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [3, 6]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [2, 5]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [2, 3]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [6, 5]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [6, 3]])).to eql(true)
      expect(@validator.valid_move?([[4, 4], [4, 3]])).to eql(false)

      @board.update_piece_loc(@board.board[:"44"], @board.board[:"45"], @board.board[:"44"].content)
      expect(@validator.valid_move?([[4, 5], [5, 3]])).to eql(true)
      expect(@validator.valid_move?([[4, 5], [3, 3]])).to eql(true)
    end
  end

  describe "#check_for_threat" do
    before(:each) do
      @board = Board.new
      @en_passant = {pawns: []}
      @validator = Validator.new(@board, [@board.white_pieces, @board.black_pieces], @en_passant)
    end

    it "Uses the passed target." do
      @board.update_piece_loc(@board.board[:"18"], @board.board[:"45"], @board.board[:"18"].content)
      @board.update_piece_loc(@board.board[:"31"], @board.board[:"44"], @board.board[:"31"].content)
      expect(@validator.check_for_threat(
        @validator.player_pieces[1],
        @validator.player_pieces[0],
        @board.board[:"44"])
      ).to eql(@board.board[:"45"].content)
    end

    it "Finds and uses the king." do
      @board.update_piece_loc(@board.board[:"18"], @board.board[:"45"], @board.board[:"18"].content)
      @board.update_piece_loc(@board.board[:"51"], @board.board[:"44"], @board.board[:"51"].content)
      expect(@validator.check_for_threat(
        @validator.player_pieces[1],
        @validator.player_pieces[0])
      ).to eql(@board.board[:"45"].content)
    end

    it "Doesn't find threats when there are none." do
      expect(@validator.check_for_threat(
        @validator.player_pieces[1],
        @validator.player_pieces[0])
      ).to eql(nil)
    end
  end

  describe "#checkmate?" do
    before(:each) do
      @board = Board.new
      @board.board.each { |_, square| square.content = " " }
      @board.white_pieces = []
      @board.black_pieces = []
      @en_passant = {pawns: []}
      @validator = Validator.new(@board, [@board.white_pieces, @board.black_pieces], @en_passant)
      @board.white_pieces << Piece.new([4, 2], "king", "white", @board.board)
      @board.white_pieces << Piece.new([3, 2], "pawn", "white", @board.board)
      @board.white_pieces << Piece.new([5, 2], "pawn", "white", @board.board)
      @board.black_pieces << Piece.new([8, 1], "rook", "black", @board.board)
      @board.black_pieces << Piece.new([6, 2], "bishop", "black", @board.board)
      @board.black_pieces << Piece.new([5, 4], "knight", "black", @board.board)
      @validator.player_pieces.reverse!
    end

    it "Returns vs knights correctly." do
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"54"].content)).to eql(false)
      @board.black_pieces << Piece.new([3, 4], "pawn", "black", @board.board)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"54"].content)).to eql(true)
      @board.white_pieces << Piece.new([6, 3], "pawn", "white", @board.board)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"54"].content)).to eql(false)
    end

    it "Returns false correctly" do
      @board.black_pieces << Piece.new([6, 3], "rook", "black", @board.board)
      @board.black_pieces << Piece.new([3, 4], "pawn", "black", @board.board)
      @board.black_pieces << Piece.new([6, 4], "bishop", "black", @board.board)
      @board.black_pieces.delete(@board.board[:"54"].content)
      @board.board[:"54"].content = " "
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"64"].content)).to eql(false)

      @board.update_piece_loc(@board.board[:"64"], @board.board[:"51"], @board.board[:"64"].content)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"51"].content)).to eql(false)

      @board.update_piece_loc(@board.board[:"63"], @board.board[:"43"], @board.board[:"63"].content)
      @board.update_piece_loc(@board.board[:"51"], @board.board[:"44"], @board.board[:"51"].content)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"43"].content)).to eql(false)

      @board.black_pieces << Piece.new([4, 4], "rook", "black", @board.board)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"43"].content)).to eql(false)
    end

    it "Returns true correctly" do
      @board.black_pieces << Piece.new([6, 3], "rook", "black", @board.board)
      @board.black_pieces << Piece.new([3, 4], "pawn", "black", @board.board)
      @board.black_pieces << Piece.new([4, 4], "rook", "black", @board.board)
      @board.black_pieces.delete(@board.board[:"54"].content)
      @board.board[:"54"].content = " "

      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"44"].content)).to eql(true)

      @board.update_piece_loc(@board.board[:"52"], @board.board[:"88"], @board.board[:"52"].content)
      @board.white_pieces << Piece.new([5, 2], "bishop", "white", @board.board)
      @board.black_pieces.delete(@board.board[:"62"].content)
      @board.board[:"62"].content = " "
      @board.black_pieces << Piece.new([6, 2], "rook", "black", @board.board)
      expect(@validator.checkmate?(@validator.player_pieces[1], @board.board[:"44"].content)).to eql(true)
    end
  end
end

describe NewGame do
  before(:each) do
    @game = NewGame.new
  end

  it "Moves correctly" do
    allow(@game.move).to receive("move_start").and_return([[1, 2], [1, 3]])
    @game.turn()
    expect(@game.board[:"13"].content.piece_type).to eql("pawn")
    expect(@game.board[:"12"].content).to eql(" ")

    @game.player.reverse!
    @game.player_pieces.reverse!

    @game.board_class.update_piece_loc(@game.board[:"68"], @game.board[:"15"], @game.board[:"68"].content)
    allow(@game.move).to receive("move_start").and_return([[4, 2], [4, 3]], [[2, 2], [2, 3]])
    @game.turn()
    expect(@game.board[:"42"].content.piece_type).to eql("pawn")
    expect(@game.board[:"43"].content).to eql(" ")
  end

  context "Castling" do
    before(:each) do
      @game.board_class.white_pieces.delete(@game.board[:"21"].content)
      @game.board_class.white_pieces.delete(@game.board[:"31"].content)
      @game.board_class.white_pieces.delete(@game.board[:"41"].content)
      @game.board[:"21"].content = " "
      @game.board[:"31"].content = " "
      @game.board[:"41"].content = " "
    end

    it "Does not allow moves to threatened squares." do
      @game.board_class.update_piece_loc(@game.board[:"18"], @game.board[:"42"], @game.board[:"18"].content)
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("e1", "c1", "a2", "a3",)
      @game.turn()
      expect(@game.board[:"31"].content).to eql(" ")
    end

    it "Moves normally." do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("e1", "c1")
      @game.turn()
      expect(@game.board[:"31"].content.piece_type).to eql("king")
    end
  end

  context "En passant." do
    before(:each) do
      @game.board_class.update_piece_loc(@game.board[:"52"], @game.board[:"55"], @game.board[:"52"].content)
      @game.player.reverse!
      @game.player_pieces.reverse!
    end

    it "Allows capture after double move." do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("d7", "d5", "e5", "d6")
      @game.turn()
      expect(@game.en_passant[:target]).to eql(@game.board[:"45"].content)
      expect(@game.en_passant[:pawns].include?(@game.board[:"55"].content)).to eql(true)
      expect(@game.en_passant[:pawns].length).to eql(1)
      @game.turn()
      expect(@game.board[:"45"].content).to eql(" ")
    end

    it "Does not allow a capture that puts own king in check." do
      @game.board_class.update_piece_loc(@game.board[:"18"], @game.board[:"56"], @game.board[:"18"].content)
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("d7", "d5", "e5", "d6", "a2", "a3")
      @game.turn()
      @game.turn()
      expect(@game.board[:"45"].content).to_not eql(" ")
    end
  end

  context "Promotion" do
    before(:each) do
      @game.board_class.update_piece_loc(@game.board[:"18"], @game.board[:"83"], @game.board[:"18"].content)
      @game.board_class.update_piece_loc(@game.board[:"17"], @game.board[:"13"], @game.board[:"17"].content)
      @game.board_class.update_piece_loc(@game.board[:"11"], @game.board[:"86"], @game.board[:"11"].content)
      @game.board_class.update_piece_loc(@game.board[:"12"], @game.board[:"17"], @game.board[:"12"].content)
      @game.board_class.update_piece_loc(@game.board[:"13"], @game.board[:"12"], @game.board[:"13"].content)
    end

    it "Promotes to Queen" do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a8", "a2", "a1")
      allow(@game.board_class).to receive_message_chain("gets.chomp.downcase").and_return("queen")
      @game.turn()
      expect(@game.board[:"18"].content.piece_type).to eql("queen")
      @game.turn()
      expect(@game.board[:"11"].content.piece_type).to eql("queen")
    end

    it "Promotes to Knight" do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a8", "a2", "a1")
      allow(@game.board_class).to receive_message_chain("gets.chomp.downcase").and_return("knight")
      @game.turn()
      expect(@game.board[:"18"].content.piece_type).to eql("knight")
      @game.turn()
      expect(@game.board[:"11"].content.piece_type).to eql("knight")
    end

    it "Promotes to Bishop" do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a8", "a2", "a1")
      allow(@game.board_class).to receive_message_chain("gets.chomp.downcase").and_return("bishop")
      @game.turn()
      expect(@game.board[:"18"].content.piece_type).to eql("bishop")
      @game.turn()
      expect(@game.board[:"11"].content.piece_type).to eql("bishop")
    end

    it "Promotes to Rook" do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a8", "a2", "a1")
      allow(@game.board_class).to receive_message_chain("gets.chomp.downcase").and_return("rook")
      @game.turn()
      expect(@game.board[:"18"].content.piece_type).to eql("rook")
      @game.turn()
      expect(@game.board[:"11"].content.piece_type).to eql("rook")
    end

    it "Finds check after promotion." do
      @game.board_class.update_piece_loc(@game.board[:"58"], @game.board[:"28"], @game.board[:"58"].content)
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a7", "a8")
      allow(@game.board_class).to receive_message_chain("gets.chomp.downcase").and_return("queen")
      expect { @game.turn() }.to output(/you are in check/).to_stdout
    end
  end

  context "Check and Checkmate" do
    before(:each) do
      @game.board.each { |_, square| square.content = " " }
      @game.board_class.white_pieces = []
      @game.board_class.black_pieces = []
      @game.player_pieces = [@game.board_class.white_pieces, @game.board_class.black_pieces]
      @game.move.player_pieces = @game.player_pieces
      @game.validator.player_pieces = @game.player_pieces
      @game.board_class.white_pieces << Piece.new([4, 2], "king", "white", @game.board)
      @game.board_class.white_pieces << Piece.new([3, 2], "pawn", "white", @game.board)
      @game.board_class.white_pieces << Piece.new([5, 2], "pawn", "white", @game.board)
      @game.board_class.black_pieces << Piece.new([8, 1], "rook", "black", @game.board)
      @game.board_class.black_pieces << Piece.new([1, 8], "king", "black", @game.board)
      @game.board_class.black_pieces << Piece.new([6, 2], "bishop", "black", @game.board)
      @game.board_class.black_pieces << Piece.new([6, 6], "knight", "black", @game.board)
      @game.player.reverse!
      @game.player_pieces.reverse!
    end

    it "puts opponent in check." do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("f6", "e4")
      @game.board_class.print_board()
      expect { @game.turn() }.to output(/you are in check/).to_stdout
    end

    it "checkmates." do
      allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("f6", "e4")
      @game.board_class.black_pieces << Piece.new([3, 4], "pawn", "black", @game.board)
      expect { @game.turn() }.to output(/Checkmate. Black wins./).to_stdout
    end
  end

  it "does cleanup." do
    allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("a2", "a3", "a7", "a6")
    @game.turn()
    expect(@game.player[1]).to eql("white")
    expect(@game.player_pieces[1][1].player).to eql("white")
    @game.turn()
    expect(@game.player[1]).to eql("black")
    expect(@game.player_pieces[1][1].player).to eql("black")
  end
end

describe "Save/Load" do
  it "saves and loads" do
    @game = NewGame.new
    @game.board.each { |_, square| square.content = " " }
    @game.board_class.white_pieces = []
    @game.board_class.black_pieces = []
    @game.player_pieces = [@game.board_class.white_pieces, @game.board_class.black_pieces]
    @game.move.player_pieces = @game.player_pieces
    @game.validator.player_pieces = @game.player_pieces
    @game.board_class.white_pieces << Piece.new([4, 2], "king", "white", @game.board)
    @game.board_class.white_pieces << Piece.new([3, 2], "pawn", "white", @game.board)
    @game.board_class.white_pieces << Piece.new([5, 2], "pawn", "white", @game.board)
    @game.board_class.black_pieces << Piece.new([8, 1], "rook", "black", @game.board)
    @game.board_class.black_pieces << Piece.new([1, 8], "king", "black", @game.board)
    @game.board_class.black_pieces << Piece.new([6, 2], "bishop", "black", @game.board)
    @game.board_class.black_pieces << Piece.new([6, 6], "knight", "black", @game.board)
    @game.board_class.black_pieces << Piece.new([6, 4], "pawn", "black", @game.board)

    allow(@game.move).to receive_message_chain("gets.chomp.downcase").and_return("e2", "e4", "save", "f4", "e3")


    @game.turn()
    @game.turn()

    @game.board.each { |_, square| square.content = " " }
    @game.board_class.white_pieces = []
    @game.board_class.black_pieces = []
    @game.player_pieces = [@game.board_class.white_pieces, @game.board_class.black_pieces]
    @game.move.player_pieces = @game.player_pieces
    @game.validator.player_pieces = @game.player_pieces
    
    @game.load_game()
    expect(@game.player[0]).to eql("black")
    expect(@game.player_pieces).to eql([@game.board_class.black_pieces, @game.board_class.white_pieces])
    expect(@game.board[:"64"].content.piece_type).to eql("pawn")
    expect(@game.board[:"64"].content.player).to eql("black")
    expect(@game.en_passant[:target]).to eql(@game.board[:"54"].content)
    expect(@game.en_passant[:pawns]).to eql([@game.board[:"64"].content])
    expect(@game.player_pieces[0].length).to eql(5)
    expect(@game.player_pieces[1].length).to eql(3)
    File.delete("save_file.yaml")
  end
end