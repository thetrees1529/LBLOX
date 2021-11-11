pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Wrapper is ERC721("LBLOX WRAPPED ERC1155","LBWERC1155"), ERC1155Holder {
    using Counters for Counters.Counter;

    Counters.Counter idCounter;

    struct TokenInfo {
        IERC1155 token;
        uint tokenId;
        uint value;
    }

    mapping(uint => TokenInfo) _tokenInfo;

    event Wrapped(address from, IERC1155 token, uint tokenId, uint value, uint wrappedTokenId);
    event Unwrapped(address from, IERC1155 token, uint tokenId, uint value, uint wrappedTokenId);

    function _wrap(address _from, IERC1155 _token, uint _tokenId, uint _value) private {
        uint id = idCounter.current();
        _token.safeTransferFrom(_from, address(this), _tokenId, _value, "");
        _mint(_from, _tokenId);
        _tokenInfo[id] = TokenInfo(_token, _tokenId, _value);
        idCounter.increment();
        emit Wrapped(_from, _token, _tokenId, _value, id);
    }

    function _unwrap(address _to, uint _tokenId) private {
        TokenInfo storage tokenInfo = _tokenInfo[_tokenId];
        safeTransferFrom(_to, address(this), _tokenId);
        tokenInfo.token.safeTransferFrom(address(this), _to, tokenInfo.tokenId, tokenInfo.value, "");
        emit Unwrapped(_to, tokenInfo.token, tokenInfo.tokenId, tokenInfo.value, _tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC721) returns(bool) {
        return ERC1155Receiver.supportsInterface(interfaceId);
    }
}