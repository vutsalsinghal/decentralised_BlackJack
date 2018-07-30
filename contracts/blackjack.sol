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
    uint public bet_amount;                                                     // Bet amount
    uint public minimum_bet;                                                    // Min  bet value;
    uint public max_wait;                                                       // Max wait after player's last move before ending the game
    uint public bet_start;                                                      // Time of the last move by the player
    
    uint8 private player_score;                                                 // Total sum of player's cards value
    uint8 private player_TotalCards;                                            // No. of cards opened by player
    uint8 private dealer_score;                                                 // Total sum of dealer's cards value
    uint8 private dealer_TotalCards;                                            // No. of cards opened by dealer
    
    uint8[] private player_cards;                                               // Array of player's open cards
    uint8[] private dealer_cards;                                               // Array of dealer's open cards
    uint8[] private deck_count;                                                 // Keep count of each of 13 cards
    
    address private casino_owner;                                               // Owner of casino
    address private playerAddr;                                                 // player's address
    
    
    //----------------------------------------- Modifiers -----------------------------------------\\
    
    modifier isdealerBalanceSufficient (uint _bet_amt){                         // Check if dealer has sufficient balance to host Blackjack game               
        require(address(this).balance >= 2*_bet_amt, "Casino should have enough balance for gameplay");
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
        minimum_bet = 0.01 ether;                                               // default values; can be changed using changeValues()
        max_wait = 200;
        
        for(uint8 i = 0; i < 13; i++) {
            deck_count[i] = 4;
        }
    }
    
    // Entry point for placing bet
    function placeBet() public payable isdealerBalanceSufficient(msg.value) returns(uint8[] playerCards, uint8[] dealerCards){
        require(msg.value >= minimum_bet, "Bet amt should be >= min bet amt");  //Check if player has placed atleast the minimum beting amount
        require(playerAddr == 0, "Play already going on");

        bet_amount = msg.value;
        playerAddr = msg.sender;

        uint8 drawCard1 = _shuffleAndTake();
        uint8 drawCard2 = _shuffleAndTake();
        uint8 drawCard3 = _shuffleAndTake();

        dealer_cards[dealer_TotalCards++] = drawCard1;                          // dealer draws 1 card
        player_cards[player_TotalCards++] = drawCard2;                          // Player draws 2 cards
        player_cards[player_TotalCards++] = drawCard3;
        
        dealer_score += drawCard1;
        player_score += (drawCard2 + drawCard3);
        
        if ((player_score + 9) == 21){
            _endgame();
        } else{
            bet_start = now;
        }
        
        return (player_cards, dealer_cards);
    }
    
    // Hit, called by player
    function hit() public isPlayer returns(uint8 card, uint8[] playerCards) {
        if(now > (bet_start + max_wait)){                                       // Player has to hit withen max_wait period
            _endgame();
        } else {
            card = _shuffleAndTake();
            player_cards[player_TotalCards++] = card;
            player_score += card;

            if (player_score > 21){                                             // Busted!
                reset_game();
            } else{
                bet_start = now;
            }
        }

        return (card, player_cards);
    }

    // view function to check player's cards
    function viewPlayerCards() view public isPlayer returns(uint playerScore, uint8 totAces){
        totAces = 0;
        for (uint8 i = 0; i < player_TotalCards; i++){
            if(player_cards[i] == 1) totAces++;
        }
        
        return (player_score, totAces);
    }

    // Function to be called by player when he wants to stop
    function revealAndStop() public isPlayer returns(bool result, uint8 playerScore, uint8 dealerScore){
       return (_endgame(), player_score, dealer_score);
    }
    
    // Function to check cards and end game
    function _endgame() internal returns(bool result){
        result = false;

        for (uint8 i = 0; i < player_TotalCards; i++) {
            if (player_cards[i] == 1 && player_score + 11 <= 21)                // Ace = 1 or 11
                player_score += 11;
        }

        if (player_score > 21 ){                                                // Busted!
            result = false;
        } else{
            _revealDealerCards();                                               // Dealer draws till dealer_score <= 17

            if(dealer_score > 21 || player_score > dealer_score){
                playerAddr.transfer(2*bet_amount);                              // Player wins 2*bet_amount
                result = true;
            } else if(player_score == dealer_score){
                playerAddr.transfer(bet_amount);                                // Player gets back his bet_amount
                result = false;
            }
        }

        reset_game();
    }

    // Reveals draws of dealer, dealer draws all cards at the end, to prevent revealing
    function _revealDealerCards() internal{
        uint8 card;
        uint8 _totAces = 0;
        
        while (dealer_score <= 17){                                             // Dealer draws till score <= 17
            card = _shuffleAndTake();
            dealer_score += card;
            if (card == 1) _totAces++;
        }
    
        if (dealer_score < 21){
            for (uint8 i = 0; i < _totAces; i++){
                if (dealer_score + 9 <= 21) dealer_score += 9;
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

    function ifPlayerUnresponsive() external onlyOwner{
        if(now > bet_start + max_wait) {                                        // Owner can end game (after wait period is over) if player is unresponsive
            _endgame();
        } else {

        }
    }

    function changeValues(uint _minimum_bet, uint _max_wait) external onlyOwner{
        minimum_bet = _minimum_bet;
        max_wait = _max_wait;
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
