pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
contract Random {
    uint nonce;
    function _randomNumber(uint _upTo) internal returns(uint number ) {
        number = uint(keccak256(abi.encodePacked(block.timestamp, "peepeepoopoo", nonce))) % _upTo;
        nonce ++;
    }
}
contract LotteryContract is Ownable, Random {
    constructor() {
        lotteries[id].status = STATUS.ended;
    }
    enum STATUS {takingtickets, awaitingdraw, ended, cancelled}
    event LotteryStarted(uint indexed id);
    event LotteryEnded(uint indexed id);
    event LotteryCancelled(uint indexed id);
    event TicketsBought(uint indexed id, address indexed buyer, uint howMany);
    event Win(uint indexed id, address indexed winner, uint amount);
    
    //data
    uint public id;
    mapping(uint => Lottery) lotteries;
    struct Lottery {
        //lottery variables
        STATUS status;
        PrizeData prizeData;
        uint prizeIndex;
        uint pot;
        uint percentage;
        address profitTaker;
        uint endsAt;
        //where all the tickets go
        address[] tickets;
        //price of tickets
        uint ticketPrice;
        //winner data
        Winner[] winners;
        //in the case of cancelling, people can refund their tickets
        mapping(address => bool) refundClaimed;
        mapping(address => uint) ticketsBought;
    }
    struct PrizeData {
        uint totalWeight;
        uint[] weightings;
    }
    struct Winner {
        address addr;
        uint amount;
    }
    
    
    //main functions
    function startLottery(uint[] memory _prizeWeightings, uint _percentage, address _profitTaker, uint _endsAt, uint _ticketPrice) public onlyOwner {
        Lottery storage lottery = lotteries[id];
        require(lottery.status == STATUS.ended || lottery.status == STATUS.cancelled, "Lottery is still in progress.");
        id ++;
        lottery = lotteries[id];
        lottery.prizeData.weightings = _prizeWeightings;
        lottery.percentage = _percentage;
        lottery.profitTaker = _profitTaker;
        lottery.endsAt = _endsAt;
        lottery.ticketPrice = _ticketPrice;
        for(uint i; i < _prizeWeightings.length; i ++) {
            lottery.prizeData.totalWeight += _prizeWeightings[i];
        }
        lottery.status = STATUS.takingtickets;
        emit LotteryStarted(id);
    }
    
    function closeTicketOffice() public onlyOwner {
        Lottery storage lottery = lotteries[id];
        require(block.timestamp >= lottery.endsAt, "Too early to begin draw.");
        require(lottery.status == STATUS.takingtickets, "Lottery already isn't taking tickets right now.");
        lottery.status = STATUS.awaitingdraw;
    }
    
    function drawPrize() public onlyOwner {
        Lottery storage lottery = lotteries[id];
        require(lottery.status == STATUS.awaitingdraw, "Lottery is not awaiting any draws.");
        uint prize = getNextPrize();
        address winner = lottery.tickets[_randomNumber(lottery.tickets.length)];
        winner.call{value: prize}("");
        emit Win(id, winner, prize);
        lottery.winners.push(Winner(winner, prize));
        if(lottery.prizeIndex == lottery.prizeData.weightings.length - 1) {
            lottery.status = STATUS.ended;
            emit LotteryEnded(id);
        } else {
            lottery.prizeIndex ++;    
        }
    }
    
    function cancelLottery() public onlyOwner {
        Lottery storage lottery = lotteries[id];
        require(lottery.status != STATUS.ended, "Lottery already ended.");
        require(lottery.status != STATUS.cancelled, "Lottery already cancelled.");
        lottery.status = STATUS.cancelled;
        emit LotteryCancelled(id);
    }
    
    //current lottery view functions
    function getPot() public view returns(uint) {
        return getPotAt(id);
    }
    
    function getTicketPrice() public view returns(uint) {
        return getTicketPriceAt(id);
    }
    
    function getEndsAt() public view returns(uint) {
        return getEndsAtAt(id);
    }
    
    function getMyTicketCount() public view returns(uint) {
        return getTicketCountAtFor(id, msg.sender);
    }
    
    function getNextPrizeIndex() public view returns(uint) {
        return getPrizeIndexAt(id);
    }

    function getNextPrize() public view returns(uint) {
        return getNextPrizeAt(id);
    }
    
    function getPrizes() public view returns(uint[] memory) {
        return getPrizesAt(id);
    }

    function getRemainingPrizes() public view returns(uint[] memory prizes) {
        return getRemainingPrizesAt(id);
    }
    
    function getPrizeFor(uint _index) public view returns(uint) {
        return getPrizeAtFor(id, _index);
    }
    
    function getTotalTickets() public view returns(uint) {
        return getTotalTicketsAt(id);
    }
    
    function getStatus() public view returns(STATUS) {
        return getStatusAt(id);
    }

    function getWinners() public view returns(Winner[] memory) {
        return getWinnersAt(id);
    }

    function getRefundableTicketCount() public view returns(uint) {
        return getRefundableTicketCountAtFor(id, msg.sender);
    }
    
    //view functions
    function getPotAt(uint _id) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.pot;
    }
    
    function getTicketPriceAt(uint _id) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.ticketPrice;
    }
    
    function getEndsAtAt(uint _id) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.endsAt;
    }
    
    function getTicketCountAtFor(uint _id, address _addr) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.ticketsBought[_addr];
    }
    
    function getPrizeIndexAt(uint _id) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.prizeIndex;
    }

    function getNextPrizeAt(uint _id) public view returns(uint prize) {
        Lottery storage lottery = lotteries[_id];
        if(lottery.prizeData.weightings.length > 0) {
            prize = getPrizeAtFor(_id, lottery.prizeIndex);    
        }
    }
    
    function getPrizesAt(uint _id) public view returns(uint[] memory prizes) {
        return getPrizesAtFrom(_id, 0);
    }
    
    function getPrizesAtFrom(uint _id, uint _from) public view returns(uint[] memory prizes) {
        Lottery storage lottery = lotteries[_id];
        prizes = new uint[](lottery.prizeData.weightings.length - _from);
        for(uint i = _from; i < lottery.prizeData.weightings.length; i ++) {
            prizes[i] = getPrizeAtFor(_id, i);
        }
    }
    
    function getRemainingPrizesAt(uint _id) public view returns(uint[] memory prizes) {
        Lottery storage lottery = lotteries[_id];
        if(lottery.status != STATUS.cancelled) {
            prizes = getPrizesAtFrom(id, lottery.prizeIndex);
        }
    }

    function getPrizeAtFor(uint _id, uint _index) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        uint multiplier = lottery.pot / lottery.prizeData.totalWeight;
        return lottery.prizeData.weightings[_index] * multiplier;
    }
    
    function getTotalTicketsAt(uint _id) public view returns(uint) {
        Lottery storage lottery = lotteries[_id];
        return lottery.tickets.length;
    }
    
    function getStatusAt(uint _id) public view returns(STATUS) {
        Lottery storage lottery = lotteries[_id];
        return lottery.status;
    }
    
    function getWinnersAt(uint _id) public view returns(Winner[] memory) {
        Lottery storage lottery = lotteries[_id];
        return lottery.winners;
    }

    function getRefundableTicketCountAtFor(uint _id, address _addr) public view returns(uint refundable) {
        Lottery storage lottery = lotteries[_id];
        if (lottery.status == STATUS.cancelled && !lottery.refundClaimed[_addr]) {
            refundable = lottery.ticketsBought[_addr];
        }
    }
    

    //user functions
    function buyTickets() public payable {
        Lottery storage lottery = lotteries[id];
        require(lottery.status == STATUS.takingtickets);
        uint ticketCount = msg.value / lottery.ticketPrice;
        uint toTake = lottery.ticketPrice * ticketCount;
        uint toPot = (toTake * lottery.percentage) / 100;
        uint toProfitTaker = toTake - toPot;
        lottery.pot += toPot;
        lottery.ticketsBought[msg.sender] += ticketCount;
        for(uint i; i < ticketCount; i ++) {
            lottery.tickets.push(msg.sender);
        }
        msg.sender.call{value: msg.value - toTake}("");
        lottery.profitTaker.call{value: toProfitTaker}("");
        emit TicketsBought(id, msg.sender, ticketCount);
    }
    
    function refundTickets() public {
        refundTicketsAt(id);
    }

    function refundTicketsAt(uint _id) public {
        Lottery storage lottery = lotteries[_id];
        require(getRefundableTicketCountAtFor(id, msg.sender) > 0, "No tickets to claim at this address.");
        lottery.refundClaimed[msg.sender] = true;
        (bool success,) = msg.sender.call{value: lottery.ticketPrice * lottery.ticketsBought[msg.sender]}("");
        require(success, "Lottery cannot honour your refund request right now; please try again later.");
    }

    receive() external payable {
    }
    
}