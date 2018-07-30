pragma solidity ^0.4.24;


/**
 * @title  - Decentralised BlackJack
 * 
 * @author - Vutsal Singhal <vutsalsinghal[at]gmail[dot]com>
 * @author - Amit Panghal <panghalamit1892[at]gmail[dot]com>
 * 
 * @notice - 
 * @dev    - 
 */


contract BlackJack{
    uint public bet_amount;                                                     // bet amount
    uint public minimum_bet;                                                    // minimum  bet value;
    uint public max_wait;                                                       // maximum wait after player's last move before ending the game
    uint public bet_start;                                                      // time of the last move by the player
    
    uint8 private player_score;                                                 // total sum of player's cards value
    uint8 private player_TotalCards;                                            // no. of cards opened by player
    
    uint8[] private player_cards;                                               // array of player's open cards
    uint8[] private deck_count;                                                 // keep count of each of 13 cards
    
    address private casino_owner;                                               // owner of casino
    address private playerAddr;                                                 // player's address
    
    
    //----------------------------------------- Modifiers -----------------------------------------\\
    
    modifier isdealerBalanceSufficient (uint val, uint _minimum_bet){           // Check if dealer has sufficient balance to host Blackjack game               
        require(val >= (3*minimum_bet), "Casino should have enough balance for gameplay");
        _;
    }
    
    modifier isPlayer{
        require(playerAddr == msg.sender, "only player can call game functions");
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
        minimum_bet = 0.01 ether;
        max_wait = 200;
        
        for(uint8 i = 0; i < 13; i++) {
            deck_count[i] = 4;
        }
    }
    
    // Entry point for placing bet
    function placeBet() public payable returns(uint8[2] _playerCards){
        require(msg.value >= minimum_bet, "Bet amt should be >= min bet amt");  //Check if player has placed atleast the minimum beting amount
        require(playerAddr == 0, "Play already going on");

        bet_amount = msg.value;
        playerAddr = msg.sender;
        _playerCards[0] = _shuffleAndTake();
        _playerCards[1] = _shuffleAndTake();
        player_cards[player_TotalCards++] = _playerCards[0];
        player_cards[player_TotalCards++] = _playerCards[1];
        player_score += (_playerCards[0] + _playerCards[1]);
        
        if ((player_score + 9) == 21) {
            _endgame();
        } else
        bet_start = now;
    }
    
    // Hit, called by player
    function hit() public isPlayer returns(uint8 card) {
        if(now > bet_start + max_wait) {                                        // Player has to hit withen max_wait period
            _endgame();
        } else {
            card = _shuffleAndTake();
            player_cards[player_TotalCards++] = card;
            player_score += card;

            if (player_score > 21) reset_game();                                // Busted!

            bet_start = now;
        }
    }

    // view function to check player's cards
    function viewPlayerCards() view public isPlayer returns(uint _playerTotal, uint _aceCount){
        _playerTotal = player_score;
        _aceCount = 0;
        for (uint8 i = 0; i < player_TotalCards; i++){
            if(player_cards[i] == 1) _aceCount++;
        }
    }

    // Function to be called by player when he wants to stop
    function revealandStop() public isPlayer returns(bool _result) {
       _result = _endgame();
    }
    
    // Function to check cards and end game
    function _endgame() internal returns(bool _result) {
         uint8 dealerScore =_revealDealerCards();
        _result = false;
        
        for (uint8 i = 0; i < player_TotalCards; i++) {
            if (player_cards[i] == 1 && player_score + 9 <= 21)
                player_score += 9;
        }
        if (player_score > 21 ){                                                // Busted!
            
        } else if(dealerScore > 21 || player_score > dealerScore) {             // Player wins
            playerAddr.transfer(2*bet_amount);
            _result = true;
        } else if(player_score == dealerScore) {
            playerAddr.transfer(bet_amount);
            _result = false;
        }
        
        reset_game();
    }

    // Reveals draws of dealer, dealer draws all cards at the end, to prevent revealing
    function _revealDealerCards() internal returns(uint8 dealerScore){
        dealerScore = 0;
        uint8 card;
        uint8 ace_count = 0;
        
        for (uint8 i = 0; i < player_TotalCards; i++){
            card = _shuffleAndTake();
            dealerScore += card;
            if (card == 1) ace_count++;
        }
    
        if (dealerScore < 21){
            for (i = 0; i < ace_count; i++){
                if (dealerScore + 9 <= 21) dealerScore += 9;
            }
        }
    }

    // Function to help in random card pick
    function _getRandom() internal view returns(uint rand){
        bytes32 hashval = keccak256(abi.encodePacked(now, playerAddr, bet_start, player_TotalCards));
        rand = uint256(hashval);
    }

    // Pick a card from the deck
    function _shuffleAndTake() internal returns(uint8 card) {
        bool card_found = false;
        while(!card_found){
            uint _rand = (_getRandom() % 52) + 1;
            if (deck_count[_rand % 13] > 0){                                    // Check if any of the suits is left
                card = uint8(_rand % 13 + 1);

                if (card > 10){                                                 // All face cards have value = 10
                    card = 10;
                }

                deck_count[_rand % 13]--;
                card_found = true;
            }
        }
        
    }

    function reset_game() internal{
        playerAddr = 0;
        bet_amount = 0;
        player_TotalCards = 0;
        bet_start = 0;
        
        for (uint8 i = 0; i < 13; i++){
            deck_count[i] = 4;
        }
    }
    
    function transferToDealer() public payable{}                                // Anyone can send Ether to contract
   
    function transferFromDealer(uint _amount) external onlyOwner{
        casino_owner.transfer(_amount);
    }
    
    function kill() public onlyOwner{                                           // destroy contract
        selfdestruct(casino_owner);
    }
}
