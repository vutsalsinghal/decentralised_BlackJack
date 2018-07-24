pragma solidity ^0.4.19;

contract Casino{
    
    address player;
    address bet_amount;
    uint[] cards_opened;
    
    //encrypted dealer card, happpens off-chain 
    bytes32[] dealer_cards;
    uint minimum_bet;
    uint max_wait;
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    constructor(uint minimum_bet, uint max_wait) public {
        owner = msg.sender;
    }
    
    function _revealDealerCards() internal (uint) {
        
    }
    
    function placeBet() public payable {
        
    }
    
    function revealandStop() public  {
        
    }
    
    function viewPlayerCards() public view (uint total) {
        
    }
    
    function kill() public onlyOwner{
    // destroy contract
        selfdestruct(owner);
    }
}
