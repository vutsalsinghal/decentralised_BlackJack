pragma solidity ^0.4.24;

contract Casino{
    uint private bet_amount;                                                    //bet amount
    uint public minimum_bet;                                                    // minimum  bet value;
    uint private max_wait;                                                      // maximum wait after player's last move before ending the game
    uint public bet_start;                                                      // time of the last move by the player
    
    uint8 private player_count;                                                 // total count of player's cards
    uint8 private num_opened;                                                   // number of cards opened by player
    
    uint8[] private cards_opened;                                               //player's opened cards;
    uint8[] private deck_count;                                                 // keep count of each of 13 cards
    
    address private casino_owner;                                               //owner of casino
    address private player;                                                     // player's address
    
    
    //----------------- Modifiers ------------------\\
    
    modifier isDepositEnough (uint val, uint _minimum_bet)                      // Check if dealer has sufficient balance to host Blackjack game
    {                    
        require(val >= (3 * (minimum_bet/2)), "Casino should have enough balance for gameplay");
        _;
    }
    
    // Cehck if player has placed atleast the minimum beting amount
    modifier canBet(uint256 val) {
        require(val >= minimum_bet, "player should bet more than minimum amount");
        require(player == 0, "play already going on");
        _;
    }
    
    // Is caller already playing
    modifier isPlayer(address _player) {
        require(_player == msg.sender, "only player can call game functions");
        _;
    }
    
    // Check if address is owner of contract
    modifier onlyOwner {
        require(msg.sender == casino_owner, "only owner can withdraw");
        _;
    }
    
    //----------------- Constructor ------------------\\
    constructor(uint _minimum_bet, uint _max_wait) public payable isDepositEnough(msg.value, _minimum_bet){
        casino_owner = msg.sender;
        minimum_bet = _minimum_bet;
        max_wait = _max_wait;
        
        for(uint i=0; i<13; i++) {
            deck_count[i] = 4;
        }
    }
    
    // reveals draws of dealer, dealer draws all cards at the end, to prevent revealing
    function _revealDealerCards()  internal returns (uint8 dealerScore){
        dealerScore = 0;
        uint8 ace_count=0;
        uint8 card;
        for(uint8 i=0; i<num_opened; i++) {
            card=_shuffleAndTake();
            dealerScore+=card;
            if(card == 1) ace_count++;
        }
        if(dealerScore < 21) {
            for(i=0; i<ace_count; i++) {
                if(dealerScore+9 <= 21)
                    dealerScore+=9;
            }
        }
    }
    
    function getRandom() internal view returns (uint256 rand) {
        bytes32 hashval = keccak256(abi.encodePacked(now, player, bet_start,num_opened));
        rand = uint256(hashval);
    }
    
    // picking a card from deck
    function _shuffleAndTake() internal returns (uint8 _card) {
        bool card_found=false;
        uint256 num;
        while(!card_found) {
            num = getRandom()%52+1;
            if(deck_count[num%13]>0) {
                _card = uint8(num%13 + 1);
                deck_count[num%13]--;
                card_found=true;
            }
        }
        
    }
    
    // entry point for placing bet
    function placeBet() public payable canBet(msg.value) returns (uint8[2] _playerCards){
        bet_amount = msg.value;
        player = msg.sender;
        _playerCards[0] = _shuffleAndTake();
        _playerCards[1] = _shuffleAndTake();
        cards_opened[num_opened++] = _playerCards[0];
        cards_opened[num_opened++] = _playerCards[1];
        player_count += _playerCards[0];
        player_count += _playerCards[1];
        if(player_count+9 == 21) {
            _endgame();
        } else 
        bet_start = now;
    }
    
    // hit, called by player
    function hit() public isPlayer(msg.sender) returns (uint8 card) {
        if(now > bet_start+max_wait) {
            //stop game and send money to whoever wins
            _endgame();
        } else {
            card = _shuffleAndTake();
            cards_opened[num_opened++] = card;
            player_count += card;
            if(player_count > 21) {
                //bust
                player=0;
                bet_amount=0;
                num_opened=0;
                bet_start=0;
                for(uint8 i=0; i<13; i++) {
                    deck_count[i] = 4;
                }
            }
            bet_start=now;
        }
    }
    
    // function to check cards and end game
    function _endgame() internal returns (bool _result) {
         uint8 dealerScore=_revealDealerCards();
        _result = false;
        for(uint8 i=0; i<num_opened; i++) {
            if(cards_opened[i] == 1 && player_count+9 <= 21)
                player_count+=9;
        }
        if(player_count > 21 ) {
            //bust
        } else if(dealerScore > 21 || player_count > dealerScore) {
            //player wins
            player.transfer(2*bet_amount);
            _result = true;
        } else if(player_count == dealerScore) {
            player.transfer(bet_amount);
            _result = false;
        }
        player = 0;
        bet_amount=0;
        num_opened=0;
        bet_start=0;
        for(i=0; i<13; i++) {
            deck_count[i] = 4;
        }
    }
    
    // function to be called by player when he wants to stop
    function revealandStop() public isPlayer(msg.sender) returns (bool _result) {
       _result = _endgame();
    }
    
    
    function withdraw() public onlyOwner{
        if(now > bet_start + max_wait) {
            _endgame();
        } else if(player == 0) {
            casino_owner.transfer(address(this).balance);
        }
        
    }
    // view function to check player's cards
    function viewPlayerCards() public view returns (uint _playerTotal, uint _aceCount) {
        _playerTotal = player_count;
        _aceCount=0;
        for(uint8 i=0; i<num_opened; i++) {
            if(cards_opened[i] == 1)
                _aceCount++;
        }
     
    }
    
    function kill() public onlyOwner{
    // destroy contract
        selfdestruct(casino_owner);
    }
    
}
