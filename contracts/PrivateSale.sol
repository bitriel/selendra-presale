// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IPreIDOBase.sol";

// TODO: set releaseOnBlock to fixed block

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
  uint256 public constant LOCK_DURATION = 730 days; // 2 years;
  /// @dev the default token price for private sale in 4 decimals
  uint256 public constant TOKEN_PRICEX4 = 165; // // 165 = 0.0165 * 10^4
  /// @dev balanceOf[investor] = balance
  mapping(address => uint256) public override balanceOf;
  /// @dev orderIds[investor] = array of order ids
  mapping(address => uint256[]) private orderIds;
  /// @dev orders[orderId] = OrderInfo
  mapping(uint256 => OrderInfo) public override orders;
  /// @dev The latest order id for tracking order info
  uint256 private latestOrderId = 0;
  /// @notice The token used for private sale
  IERC20Metadata public immutable override token;
  /// @notice The total amount of tokens had been distributed 
  uint256 public totalDistributed;
  /// @notice The total amount of funds raised in USD with 8 decimals
  uint256 public fundsRaisedX8;

  constructor(address _token) {
    require(_token != address(0), "ITA"); // invalid token address
    token = IERC20Metadata(_token);
  }

  function investorOrderIds(address investor) external view override returns(uint256[] memory ids) {
    uint256[] memory arr = orderIds[investor];
    return arr;
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
    balanceOf[recipient] = balanceOf[recipient].add(amount);
    orderIds[recipient].push(latestOrderId);
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
    balanceOf[orderInfo.beneficiary] = balanceOf[orderInfo.beneficiary].sub(orderInfo.amount);

    emit UnlockTokens(orderInfo.beneficiary, orderId, orderInfo.amount);
  }

  function rewardInvestor(address _to, uint256 _amount) public onlyOwner {
    require(_to != address(0), "IAA"); // invalid account address
    require(_amount > 0, "IAV"); // invalid amount value
    
    token.safeTransferFrom(msg.sender, _to, _amount);
  }
}