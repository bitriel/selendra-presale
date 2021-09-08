// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TimeLock {
  using SafeMath for uint256;

  struct LockInfo {
    uint256 balance;
    uint256 releaseFundsOnBlock;
  }

  IERC20 public token;

  /// @dev locksInfo[investor] => lockInfo
  mapping(address => LockInfo) public locksInfo;

  event LockFunds(address sender, uint256 amount, uint256 releaseFundsOnBlock);   
  event UnlockFunds(address receiver, uint256 amount);

  constructor(address _token) {
    token = IERC20(_token);
  }

  function deposit(address investor, uint256 amount, uint256 releaseFundsOnBlock) external returns(bool success) {
    require(token.transferFrom(investor, address(this), amount), "FTF"); // failed to transfer funds
    require(block.number < releaseFundsOnBlock, "LBN"); // must be greater than current block number
    locksInfo[investor].balance = locksInfo[investor].balance.add(amount);
    locksInfo[investor].releaseFundsOnBlock = releaseFundsOnBlock;
    emit LockFunds(investor, amount, releaseFundsOnBlock);
    return true;
  }

  function withdraw(address investor) public returns(bool success) {
    LockInfo storage lockInfo = locksInfo[investor];
    require(lockInfo.balance > 0, "ZB"); // zero balance
    require(block.number >= lockInfo.releaseFundsOnBlock, "FNU"); // funds is not yet unlocked
    uint256 balance = lockInfo.balance;
    require(token.transfer(investor, balance), "FTF"); // failed to transfer funds
    lockInfo.balance = 0;
    emit UnlockFunds(investor, balance);
    return true;
  }    
}