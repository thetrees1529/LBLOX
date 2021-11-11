//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Wrapper is Context, Ownable, ERC721("LBLOX WRAPPED ERC1155","LBWERC1155"),  ERC721Holder, ERC721Enumerable, ERC1155Holder {
    using Counters for Counters.Counter;
    using Strings for uint;

    Counters.Counter idCounter;

    struct WrapInfo {
        ERC1155 token;
        uint tokenId;
        uint value;
    }

    mapping(uint => WrapInfo) _wrapInfo;
    mapping(ERC1155 => string) _baseURIs;

    event Wrapped(address from, ERC1155 token, uint tokenId, uint value, uint wrappedTokenId);
    event Unwrapped(address from, ERC1155 token, uint tokenId, uint value, uint wrappedTokenId);

    function unwrap(uint _tokenId) public {
        address sender = _msgSender();
        _unwrap(sender, _tokenId);
    }

    function getWrapInfo(uint _tokenId) public view returns(WrapInfo memory) {
        return _getWrapInfo(_tokenId);
    }

    function tokenURI(uint _tokenId) public override view returns(string memory) {
        WrapInfo storage wrapInfo = _getWrapInfo(_tokenId);
        string memory baseURI = _getBaseURI(wrapInfo.token);
        string memory uri = wrapInfo.token.uri(wrapInfo.tokenId);
        return string(abi.encodePacked(baseURI, uri));
    }
    
    function onERC1155Received(
        address _from,
        address,
        uint256 _tokenId,
        uint256 _value,
        bytes memory
    ) public override returns (bytes4) {
        _wrap(_from, ERC1155(_msgSender()), _tokenId, _value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address _from,
        address,
        uint256[] memory _tokenIds,
        uint256[] memory _values,
        bytes memory _data
    ) public override returns (bytes4) {
        ERC1155(_msgSender()).safeBatchTransferFrom(address(this), _from, _tokenIds, _values, _data);
        return this.onERC1155BatchReceived.selector;
    }

    function getBaseURI(ERC1155 _for) public view returns(string memory) {
        return _getBaseURI(_for);
    }

    function setBaseURI(ERC1155 _for, string calldata _baseURI) public onlyOwner {
        _setBaseURI(_for, _baseURI);
    } 

    function _wrap(address _from, ERC1155 _token, uint _tokenId, uint _value) private {
        uint wrapId = idCounter.current();
        _mint(_from, _tokenId);
        _setWrapInfo(wrapId, _token, _tokenId, _value);(_token, "", _tokenId, _value);
        idCounter.increment();
        emit Wrapped(_from, _token, _tokenId, _value, wrapId);
    }

    function _unwrap(address _to, uint _tokenId) private {
        WrapInfo storage wrapInfo = _getWrapInfo(_tokenId);
        safeTransferFrom(_to, address(this), _tokenId);
        wrapInfo.token.safeTransferFrom(address(this), _to, wrapInfo.tokenId, wrapInfo.value, "");
        emit Unwrapped(_to, wrapInfo.token, wrapInfo.tokenId, wrapInfo.value, _tokenId);
    }

    function _getWrapInfo(uint _wrapId) private view returns(WrapInfo storage) {
        return _wrapInfo[_wrapId];
    }
    function _setWrapInfo(uint _wrapId, ERC1155 _token, uint _tokenId, uint _value) private {
        _wrapInfo[_wrapId] = WrapInfo(_token, _tokenId, _value);
    }

    function _getBaseURI(ERC1155 _for) private view returns(string memory) {
        return _baseURIs[_for];
    }
    function _setBaseURI(ERC1155 _for, string calldata _baseURI) private {
        _baseURIs[_for] = _baseURI;
    } 

    function _beforeTokenTransfer(address from, address to, uint tokenId) internal override(ERC721, ERC721Enumerable) {
        return super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC721, ERC721Enumerable) returns(bool) {
        return super.supportsInterface(interfaceId);
    }
}