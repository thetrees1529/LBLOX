pragma solidity ^0.8.0;

contract Ownable {
    address owner;
    constructor() {
        owner = msg.sender;
    }
    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }
    function changeOwner(address _newOwner) external isOwner {
        owner = _newOwner;
    }
}

contract Distributor is Ownable {
    struct FeeData {
        uint totalPoints;
        FeeEntry[] feeEntries;
    }
    struct FeeEntry {
        address feeTaker;
        uint points;
    }
    mapping(address => FeeData) addressToFeeData;
    receive() external payable {
        FeeData storage feeData = addressToFeeData[msg.sender];
        if(feeData.totalPoints > 0) {
            uint feePerPoint = msg.value / feeData.totalPoints;
            for(uint i; i < feeData.feeEntries.length; i ++) {
                feeData.feeEntries[i].feeTaker.call{value: feePerPoint * feeData.feeEntries[i].points}("");
            }    
        }
    }
    function getFeeData(address _for) isOwner public view returns(FeeData memory) {
        return addressToFeeData[_for];
    }
    function addFeeEntry(address _for, FeeEntry memory _feeEntry) isOwner public {
        FeeData storage feeData = addressToFeeData[_for];
        feeData.feeEntries.push(_feeEntry);
        feeData.totalPoints += _feeEntry.points;
    
    }
    function removeFeeEntry(address _for, uint _index) isOwner public {
        FeeData storage feeData = addressToFeeData[_for];
        feeData.totalPoints -= feeData.feeEntries[_index].points;
        for(uint i = _index + 1; i < feeData.feeEntries.length; i ++) {
            feeData.feeEntries[i - 1] = feeData.feeEntries[i];
        }
        feeData.feeEntries.pop();
    }
    function bal() public view isOwner returns(uint) {
        return address(this).balance;
    }
    function withdraw(uint _value) isOwner public {
        msg.sender.call {value: _value}("");
    }
}