//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Wrapper is Context, ERC721("LBLOX WRAPPED ERC1155","LBWERC1155"), ERC1155Holder {
    using Counters for Counters.Counter;

    Counters.Counter idCounter;

    struct WrapInfo {
        ERC1155 token;
        string uri;
        uint tokenId;
        uint value;
    }

    mapping(uint => WrapInfo) _wrapInfo;

    event Wrapped(address from, ERC1155 token, uint tokenId, uint value, uint wrappedTokenId);
    event Unwrapped(address from, ERC1155 token, uint tokenId, uint value, uint wrappedTokenId);

    function wrap(ERC1155 _token, uint _tokenId, uint _value) public {
        address sender = _msgSender();
        _wrap(sender, _token, _tokenId, _value);
    }

    function unwrap(uint _tokenId) public {
        address sender = _msgSender();
        _unwrap(sender, _tokenId);
    }

    function getWrapInfo(uint _tokenId) public view returns(WrapInfo memory) {
        return _getWrapInfo(_tokenId);
    }

    function tokenURI(uint _tokenId) public override view returns(string memory) {
        WrapInfo storage wrapInfo = _getWrapInfo(_tokenId);
        return string(abi.encodePacked(wrapInfo.uri, "/", uint2str(_tokenId)));
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

    function _wrap(address _from, ERC1155 _token, uint _tokenId, uint _value) private {
        uint wrapId = idCounter.current();
        string memory uri = _token.uri(_tokenId);
        _token.safeTransferFrom(_from, address(this), _tokenId, _value, "");
        _mint(_from, _tokenId);
        _setWrapInfo(wrapId, _token, uri, _tokenId, _value);(_token, "", _tokenId, _value);
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
    function _setWrapInfo(uint _wrapId, ERC1155 _token, string memory _uri, uint _tokenId, uint _value) private {
        _wrapInfo[_wrapId] = WrapInfo(_token, _uri, _tokenId, _value);
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC721) returns(bool) {
        return ERC1155Receiver.supportsInterface(interfaceId);
    }
}