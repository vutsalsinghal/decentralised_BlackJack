pragma solidity ^0.4.24;

/*
 * @title  - Decentralised BlackJack
 * 
 * @author - Vutsal Singhal <vutsalsinghal[at]gmail[dot]com>
 * @author - Amit Panghal <panghalamit1892[at]gmail[dot]com>
 * 
 * @notice - Any no.of players can play where each player is playing against the dealer.
*/

contract BlackJack{
    uint counter;
    uint public total_BetAmount;                                                // Total bet amount
    uint public minimum_bet;                                                    // Min  bet value;
    uint public max_wait;                                                       // Max wait after player's last move before ending the game
    uint public lastGameId;                                                     // Keep track of total no.of games in progress
    
    struct Game{
        bool gotPaid;                                                           // Player has already received winnings
        uint bet_amount;                                                        // Bet amount
        uint bet_start;                                                         // Time of the last move by the player
        uint add_time;                                                          // Owner can give a player more time
        uint8 player_score;                                                     // Total sum of player's cards value
        uint8 player_TotalCards;                                                // No. of cards opened by player
        uint8 dealer_score;                                                     // Total sum of dealer's cards value
        uint8 dealer_TotalCards;                                                // No. of cards opened by dealer
        uint8[8] player_cards;                                                  // Array of player's open cards
        uint8[8] dealer_cards;                                                  // Array of dealer's open cards
        uint8[13] deck_count;                                                   // Keep count of each of 13 cards
        address playerAddr;                                                     // Player's address
    }
    
    mapping (uint => Game) gameInfo;                                            // GameId to game instance
    mapping (address => uint) addrToGameId;                                     // Player's addr to gameId
    address private casino_owner;                                               // Owner of casino
    
    
    //----------------------------------------- Modifiers -----------------------------------------\\
    
    modifier isdealerBalanceSufficient (uint _totalBetAmt){                         // Check if dealer has sufficient balance to host Blackjack game               
        require(address(this).balance >= 2*_totalBetAmt, "Casino should have enough balance for gameplay");
        _;
    }
    
    modifier isPlayer{
        require(casino_owner != msg.sender, "only player can call game functions");
        _;
    }
    
    // Check if address is owner of contract
    modifier onlyOwner {
        require(msg.sender == casino_owner, "only owner can withdraw");
        _;
    }
    
    //----------------------------------------- Constructor -----------------------------------------\\
    constructor() public payable{
        casino_owner = msg.sender;
        minimum_bet = 0.01 ether;                                               // Default values; can be changed using changeValues()
        max_wait = 200;
        total_BetAmount = 0;
        lastGameId = 0;
    }
    
    // Entry point for placing bet
    function placeBet() public payable isdealerBalanceSufficient(msg.value+total_BetAmount) returns(uint8[8] playerCards, uint8 playerScore, uint8[8] dealerCards, uint8 dealerScore, uint profit_amt){
        require(msg.value >= minimum_bet, "Bet amt should be >= min bet amt");  // Check if player has placed atleast the min beting amount
        require(addrToGameId[msg.sender] == 0, "Play already going on");        // Check if player is not already playing
        
        total_BetAmount += msg.value;                                           // Total betting amount by all players

        addrToGameId[msg.sender] = ++lastGameId;                                // Create a new game instance
        gameInfo[lastGameId].bet_amount = msg.value;
        gameInfo[lastGameId].playerAddr = msg.sender;
        gameInfo[lastGameId].add_time = 0;                                      // Default is 0
        gameInfo[lastGameId].gotPaid = false;

        for(uint8 i = 0; i < 13; i++) {                                         // Initialize deck
            gameInfo[lastGameId].deck_count[i] = 4;
        }

        uint8 drawCard1 = _shuffleAndTake(lastGameId);
        uint8 drawCard2 = _shuffleAndTake(lastGameId);
        uint8 drawCard3 = _shuffleAndTake(lastGameId);

        gameInfo[lastGameId].dealer_cards[0] = drawCard1;                       // Dealer draws 1 card
        gameInfo[lastGameId].player_cards[0] = drawCard2;                       // Player draws 2 cards
        gameInfo[lastGameId].player_cards[1] = drawCard3;
        
        gameInfo[lastGameId].dealer_TotalCards += 1;
        gameInfo[lastGameId].player_TotalCards += 2;
        
        gameInfo[lastGameId].dealer_score += drawCard1;
        gameInfo[lastGameId].player_score += (drawCard2 + drawCard3);
        
        for (i = 0; i < 2; i++) {                                               // Player has 2 cards
            if (gameInfo[lastGameId].player_cards[i] == 1 && gameInfo[lastGameId].player_score + 10 <= 21)
                gameInfo[lastGameId].player_score += 10;                        // Check for Ace; Ace = 1 or 11
        }

        playerCards = gameInfo[lastGameId].player_cards;
        playerScore = gameInfo[lastGameId].player_score;
        dealerCards = gameInfo[lastGameId].dealer_cards;
        dealerScore = gameInfo[lastGameId].dealer_score;

        if (gameInfo[lastGameId].player_score == 21){
            (playerCards, playerScore, dealerCards, dealerScore, profit_amt) = revealAndStop();
        }else{
            gameInfo[lastGameId].bet_start = now;
        }
    }
    
    // Hit, called by player
    function hit() public isPlayer returns(uint8[8] playerCards, uint8 playerScore, uint8[8] dealerCards,  uint8 dealerScore, uint profit_amt){
        require(addrToGameId[msg.sender] != 0, "Player is not playing");        // Check if player has started playing
        uint gameId = addrToGameId[msg.sender];                                 // Get player's game instance

        //if (gameInfo[gameId].playerAddr == msg.sender){                       // Check if the same player is calling hit
        if(now>(gameInfo[gameId].bet_start+max_wait+gameInfo[gameId].add_time)){// Player has to call hit() within max_wait period
            (gameInfo[gameId].player_cards, gameInfo[gameId].player_score, gameInfo[gameId].player_cards, gameInfo[gameId].dealer_score, profit_amt) = revealAndStop();
        } else {
            uint8 card = _shuffleAndTake(gameId);
            gameInfo[gameId].player_cards[gameInfo[gameId].player_TotalCards++] = card;
            gameInfo[gameId].player_score += card;
            
            playerCards = gameInfo[gameId].player_cards;
            playerScore = gameInfo[gameId].player_score;
            dealerCards = gameInfo[gameId].dealer_cards;
            dealerScore = gameInfo[gameId].dealer_score;
            
            if (gameInfo[gameId].player_score > 21){                            // Busted!
                reset_game(gameId);
            } else{
                gameInfo[gameId].bet_start = now;
            }
        }
        
        return (playerCards, playerScore, dealerCards, dealerScore, profit_amt);
    }

    // view function to check player's cards
    function viewPlayerCards() view external isPlayer returns(uint GameID, uint8 playerScore, uint8[8] playerCards, uint8 dealerScore, uint8[8] dealerCards, uint time_left){
        require(addrToGameId[msg.sender] != 0, "Player is not playing");        // Check if player has started playing
        uint gameId = addrToGameId[msg.sender];                                 // Get player's game instance

        time_left = 0;
        if ((gameInfo[gameId].bet_start + gameInfo[gameId].add_time + max_wait + - now) > 0)
            time_left = gameInfo[gameId].bet_start + gameInfo[gameId].add_time + max_wait - now;
        return (gameId, gameInfo[gameId].player_score, gameInfo[gameId].player_cards, gameInfo[gameId].dealer_score,gameInfo[gameId].dealer_cards, time_left);
    }

    // Function to be called by player when he wants to stop
    function revealAndStop() public isPlayer returns(uint8[8] playerCards, uint8 playerScore, uint8[8] dealerCards,  uint8 dealerScore, uint profit_amt){
        require(addrToGameId[msg.sender] != 0, "Player is not playing");        // Check if player has started playing
        uint gameId = addrToGameId[msg.sender];
        (playerCards, playerScore, dealerCards, dealerScore, profit_amt) = _endgame(gameId);
    }
    
    // Function to check cards and end game
    function _endgame(uint gameId) internal returns(uint8[8] playerCards, uint8 playerScore, uint8[8] dealerCards,  uint8 dealerScore, uint profit_amt){
        require(gameInfo[gameId].gotPaid == false, 'Player is already paid!');  // Check if player has received winnings

        for (uint8 i = 0; i < gameInfo[gameId].player_TotalCards; i++) {
            // Ace = 1 or 11
            if (gameInfo[gameId].player_cards[i] == 1 && gameInfo[gameId].player_score + 10 <= 21)
                gameInfo[gameId].player_score += 10;
        }

        if (gameInfo[gameId].player_score > 21 ){                               // Busted!
            profit_amt = 0;
        } else{
            _revealDealerCards(gameId);                                         // Dealer draws till dealer_score <= 17

            if(gameInfo[gameId].dealer_score > 21 || gameInfo[gameId].player_score > gameInfo[gameId].dealer_score){
                gameInfo[gameId].gotPaid = true;
                profit_amt = 2*gameInfo[gameId].bet_amount;
                gameInfo[gameId].playerAddr.transfer(profit_amt);               // Player wins 2*bet_amount
            } else if(gameInfo[gameId].player_score == gameInfo[gameId].dealer_score){
                gameInfo[gameId].gotPaid = true;
                profit_amt = gameInfo[gameId].bet_amount;                       // Player gets back his bet_amount
                gameInfo[gameId].playerAddr.transfer(profit_amt);
            }
        }

        playerCards = gameInfo[gameId].player_cards;
        playerScore = gameInfo[gameId].player_score;
        dealerCards = gameInfo[gameId].dealer_cards;
        dealerScore = gameInfo[gameId].dealer_score;

        reset_game(gameId);
    }

    // Reveals draws of dealer, dealer draws all cards at the end, to prevent revealing
    function _revealDealerCards(uint gameId) internal{
        uint8 card;
        uint8 _totAces = 0;
        
        while (gameInfo[gameId].dealer_score <= 17){                            // Dealer draws till dealer_score <= 17
            card = _shuffleAndTake(gameId);
            gameInfo[gameId].dealer_cards[gameInfo[gameId].dealer_TotalCards++] = card;
            gameInfo[gameId].dealer_score += card;
            if (card == 1) _totAces++;
        }
    
        if (gameInfo[gameId].dealer_score < 21){
            for (uint8 i = 0; i < _totAces; i++){
                if (gameInfo[gameId].dealer_score + 10 <= 21) gameInfo[gameId].dealer_score += 10;
            }
        }
    }

    // Function to help in random card pick
    function _getRandom(uint gameId) internal returns(uint rand){
        bytes32 hashval = keccak256(abi.encodePacked(now, gameInfo[gameId].player_TotalCards, gameInfo[gameId].dealer_TotalCards, ++counter));
        rand = uint256(hashval);
    }

    // Pick a card from the deck
    function _shuffleAndTake(uint gameId) internal returns(uint8 card) {
        bool card_found = false;
        while(!card_found){
            uint _rand = (_getRandom(gameId) % 52) + 1;
            if (gameInfo[gameId].deck_count[_rand % 13] > 0){                   // Check if any of the suits is left
                card = uint8(_rand % 13 + 1);

                if (card > 10){                                                 // All face cards have value = 10
                    card = 10;
                }

                gameInfo[gameId].deck_count[_rand % 13]--;
                card_found = true;
            }
        }
    }

    function ifPlayerUnresponsive(uint gameId) external onlyOwner{
        if (now>gameInfo[gameId].bet_start+gameInfo[gameId].add_time+max_wait)  // Owner can end game (after wait period is over) if player is unresponsive
            _endgame(gameId);
    }

    function changeValues(uint _minimum_bet, uint _max_wait, uint _counter) external onlyOwner{
        minimum_bet = _minimum_bet;
        max_wait = _max_wait;
        counter = _counter;
    }

    function addTime(uint _gameId, uint _add_time) external onlyOwner{          // Owner can add more time for a specific player
        gameInfo[_gameId].add_time = _add_time;
    }

    function reset_game(uint gameId) internal{
        total_BetAmount -= gameInfo[gameId].bet_amount;
        addrToGameId[gameInfo[gameId].playerAddr] = 0;
        delete gameInfo[gameId];
    }
    
    function transferToDealer() public payable{}                                // Anyone can send Ether to contract
   
    function transferFromDealer(uint _amount) external onlyOwner{
        //require(playerAddr == 0, "Can't withdraw while game in progress");    // Check if no game in progress
        casino_owner.transfer(_amount);
    }
    
    function kill() public onlyOwner{                                           // destroy contract
        selfdestruct(casino_owner);
    }
}
