require '../chess'

describe NewGame do
  
  describe "#new_game" do
      before { @game = NewGame.new }
    
    context "First turn." do
      it "Accepts only valid input." do
        allow(@game).to receive_message_chain(:gets, :chomp, :downcase).and_return("bob", "a2", "a3")

        expect { @game.new_game() }.to output(/That is not a valid input. Please try again./).to_stdout

      end
    end
  end
end