// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IPreIDOBase.sol";

contract PrivateSale is IPreIDOBase, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20Metadata;

  struct OrderInfo {
    address beneficiary;
    uint256 amount;
    uint256 releaseOnBlock;
    bool claimed;
  }

  /// @dev the default lock duration for private sale
  uint256 public constant LOCK_DURATION = 7 minutes; // 2 * 365 days;
  /// @dev the default token price for private sale in 4 decimals
  uint256 public constant TOKEN_PRICEX4 = 165; // // 165 = 0.0165 * 10^4
  /// @dev orders[orderId] = OrderInfo
  mapping(uint256 => OrderInfo) public override orders;
  /// @dev The latest order id for tracking order info
  uint256 private latestOrderId = 0;
  /// @notice The token used for pre-sale
  IERC20Metadata public immutable override token;
  /// @notice The total amount of tokens had been distributed 
  uint256 public totalDistributed;
  /// @notice The total amount of funds raised in USD with 8 decimals
  uint256 public fundsRaisedX8;

  constructor(address _token) {
    require(_token != address(0), "ITA"); // invalid token address
    token = IERC20Metadata(_token);
  }

  function order(address recipient, uint256 amount) external onlyOwner {
    require(recipient != address(0), "IIA"); // invalid investor address
    require(amount > 0, "ITA"); // invalid token amount

    uint256 releaseOnBlock = block.number.add(LOCK_DURATION.div(3));
    // 4: priceDecimals, 8: fundsRaisedDecimals
    uint256 funds = amount.mul(TOKEN_PRICEX4).div(10 ** (token.decimals() + 4 - 8));

    token.safeTransferFrom(msg.sender, address(this), amount);
    require(token.balanceOf(address(this)) >= amount, "NEB"); // not enough tokens balance

    orders[++latestOrderId] = OrderInfo(recipient, amount, releaseOnBlock, false);
    totalDistributed = totalDistributed.add(amount);
    fundsRaisedX8 = fundsRaisedX8.add(funds);

    emit LockTokens(recipient, latestOrderId, amount, block.number, releaseOnBlock);
  }

  function redeem(uint256 orderId) external {
    require(orderId <= latestOrderId, "IOI"); // incorrect order id

    OrderInfo storage orderInfo = orders[orderId];
    require(msg.sender == orderInfo.beneficiary || msg.sender == owner(), "NOO"); // not order beneficiary or owner of contract
    require(orderInfo.amount > 0, "ITA"); // insufficient token amount to redeem
    require(block.number >= orderInfo.releaseOnBlock, "TIL"); // tokens is still in locked
    require(!orderInfo.claimed, "TAC"); // tokens is already claimed
    
    token.safeTransfer(orderInfo.beneficiary, orderInfo.amount);
    orderInfo.claimed = true;

    emit UnlockTokens(orderInfo.beneficiary, orderId, orderInfo.amount);
  }
}