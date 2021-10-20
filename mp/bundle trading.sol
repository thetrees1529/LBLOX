pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
contract BundleTrading is Ownable {
    struct ERC20 {
        IERC20 at;
        address owner;
        uint value;
    }
    struct NFT {
        IERC721 at;
        address owner;
        uint id;
    }
    struct Offer {
        bool void;
        address creator;
        string contactDetails;
        uint ONE;
        NFT[] nfts;
        ERC20[] tokens;
    }
    Offer[] offers;
    mapping(address => uint[]) ownedOffers;
    mapping(uint => mapping(uint => bool)) approvals;
    
    constructor(uint _listingFee, address _profitTaker) {
        (listingFee, profitTaker) = (_listingFee, _profitTaker);
    }
    
    //params
    uint public listingFee;
    address profitTaker;
    
    //periphery
    function list(string calldata _contactDetails, NFT[] calldata _nfts, ERC20[] calldata _tokens, uint _ONE) public payable {
        _checkItems(_nfts, _tokens, _ONE);
        _list(msg.sender, _contactDetails, _nfts, _tokens, _ONE);
    }
    function cancelListing(uint _index) public {
        require(_checkIfOwner(_offer(_index), msg.sender), "Not owner of listing.");
        _voidListing(_offer(_index));
    }
    function totalOffers() public view returns(uint) {
        return _offersLength();
    }
    function offer(uint _index) public view returns(Offer memory) {
        return _offer(_index);
    }
    function myTotalOffers() public view returns(uint) {
        return _offersLengthByOwner(msg.sender);
    }
    function myOffer(uint _index) public view returns(Offer memory) {
        return _offerByOwner(msg.sender, _index);
    }
    function approve(uint _ownedListing, uint _otherListing, bool _approval) public {
        require(_checkIfOwner(_offer(_ownedListing), msg.sender), "Not owner of listing.");
        _approve(_ownedListing, _otherListing, _approval);
    }
    function getApprovedStatus(uint _ownedListing, uint _otherListing) public view returns(bool) {
        return _approvalStatus(_ownedListing, _otherListing);
    }
    function checkMutuallyApproved(uint _ownedListing, uint _otherListing) public view returns(bool) {
        return _checkMutuallyApproved(_ownedListing, _otherListing);
    }
    function trade(uint _ownedListing, uint _otherListing) public {
        require(_checkMutuallyApproved(_ownedListing, _otherListing), "Must have mutual approval in order to trade.");
        require(_checkMutuallyNotVoid(_offer(_ownedListing), _offer(_otherListing)), "One of these bundles has been traded already.");
        _trade(_offer(_ownedListing), _offer(_otherListing));
    }
    
    //listing creation
    function _offer(uint _index) private view returns(Offer storage) {
        return offers[_index];
    }
    function _offersLength() private view returns(uint) {
        return offers.length;
    }
    function _offerByOwner(address _addr, uint _index) private view returns(Offer storage) {
        return _offer(ownedOffers[_addr][_index]);
    }
    function _ownerOf(Offer storage _listing) private view returns(address) {
        return _listing.creator;
    }
    function _checkIfOwner(Offer storage _listing, address _addr) private view returns(bool) {
        return _addr == _ownerOf(_listing);
    }
    function _offersLengthByOwner(address _addr) private view returns(uint) {
        return ownedOffers[_addr].length;
    }
    function _checkERC20Approval(ERC20 calldata _token) private view returns(bool) {
        return _token.at.allowance(_token.owner, address(this)) >= _token.value;
    }
    function _checkNFTApproval(NFT calldata nft) private view returns(bool) {
        return nft.at.getApproved(nft.id) == address(this);
    }
    function _approve(uint _index1, uint _index2, bool _approval) private {
        approvals[_index1][_index2] = _approval;
    }
    function _approvalStatus(uint _index1, uint _index2) private view returns(bool) {
        return approvals[_index1][_index2];
    }
    function _checkMutuallyApproved(uint _index1, uint _index2) private view returns(bool) {
        return _approvalStatus(_index1, _index2) && _approvalStatus(_index2, _index1);
    }
    function _voidStatus(Offer storage _listing) private view returns(bool) {
        return _listing.void;
    } 
    function _checkMutuallyNotVoid(Offer storage _listing1, Offer storage _listing2) private view returns(bool) {
        return !(_voidStatus(_listing1) || _voidStatus(_listing2));
    }
    function _checkItems(NFT[] calldata _nfts, ERC20[] calldata _tokens, uint _ONE) private view {
        for(uint i; i < _nfts.length; i ++) {
            require(_checkNFTApproval(_nfts[i]), "Please approve NFT spend.");
        }
        for(uint i; i < _tokens.length; i ++) {
            require(_checkERC20Approval(_tokens[i]), "Please approve token spend.");
        }
        require(msg.value == _ONE + listingFee);
    }
    function _voidListing(Offer storage _listing) private {
        _listing.void = true;
        _listing.owner.call{value: _listing.ONE}("");
    }
    function _addNFT(NFT[] storage _nfts, NFT calldata _nft) private {
        _nfts.push(_nft);
    }
    function _addERC20(ERC20[] storage _tokens, ERC20 calldata _token) private {
        _tokens.push(_token);
    }
    function _list(address _addr, string calldata _contactDetails, NFT[] calldata _nfts, ERC20[] calldata _tokens, uint _ONE) private {
        _payListingFee();
        uint offersLength = _offersLength();
        ownedOffers[_addr].push(offersLength);
        offers.push();
        offers[offersLength].creator = _addr;
        offers[offersLength].contactDetails = _contactDetails;
        offers[offersLength].ONE = _ONE;
        for(uint i; i < _nfts.length; i ++) {
            _addNFT(offers[offersLength].nfts, _nfts[i]);
        }
        for(uint i; i < _tokens.length; i ++) {
            _addERC20(offers[offersLength].tokens, _tokens[i]);
        }
    }
    function _payListingFee() private {
        profitTaker.call{value: listingFee}("");
    }
    
    //listing honouring 
    function _sendNFT(NFT storage _nft, address _to) private {
        _nft.at.transferFrom(_nft.owner, _to, _nft.id);
    }
    function _sendERC20(ERC20 storage _token, address _to) private {
        _token.at.transferFrom(_token.owner, _to, _token.value);
    }
    function _trade(Offer storage _offer1, Offer storage _offer2) private {
        for(uint i; i < _offer1.tokens.length; i ++) {
            _sendERC20(_offer1.tokens[i], _ownerOf(_offer2));
        }
        for(uint i; i < _offer1.nfts.length; i ++) {
            _sendNFT(_offer1.nfts[i], _ownerOf(_offer2));
        }
        for(uint i; i < _offer2.tokens.length; i ++) {
            _sendERC20(_offer2.tokens[i], _ownerOf(_offer1));
        }
        for(uint i; i < _offer2.nfts.length; i ++) {
            _sendNFT(_offer2.nfts[i], _ownerOf(_offer1));
        }
        _voidListing(_offer1);
        _voidListing(_offer2);
        _ownerOf(_offer2).call{value: _offer1.ONE}("");
        _ownerOf(_offer1).call{value: _offer2.ONE}("");
    }
    
    //owner
    function setFee(uint _listingFee, address _profitTaker) public onlyOwner {
        (listingFee, profitTaker) = (_listingFee, _profitTaker);
    }
}