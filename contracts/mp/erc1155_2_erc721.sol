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

    event Wrapped(IERC1155 token, uint tokenId, uint numberOf);

    function _wrap(address _from, IERC1155 _token, uint _tokenId, uint _value) private {
        _token.safeTransferFrom(_from, address(this), _tokenId, _value, "");
        _mint(_from, _tokenId);
        _tokenInfo[idCounter.current()] = TokenInfo(_token, _tokenId, _value);
        idCounter.increment();
    }

    function _unwrap(address _to, uint _tokenId) private {
        TokenInfo storage tokenInfo = _tokenInfo[_tokenId];
        safeTransferFrom(_to, address(this), _tokenId);
        tokenInfo.token.safeTransferFrom(address(this), _to, tokenInfo.tokenId, tokenInfo.value, "");
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC721) returns(bool) {
        return ERC1155Receiver.supportsInterface(interfaceId);
    }
}