// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

import "./interfaces/IERC20Metadata.sol";

contract SelendraSale is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20Metadata;

  event TokenOrdered(uint256 id, address senderAddress, string selendraAddress, uint256 tokenAmount);

  struct OrderInfo {
    address senderAddress;
    string selendraAddress;
    uint256 amount;
  }

  /// @dev balanceOf[investor] = balance
  mapping(address => uint256) public balanceOf;
  /// @dev orders[orderId] = OrderInfo
  OrderInfo[] public orders;
  /// @notice The minimum investment funds for purchasing tokens in USD
  uint256 public immutable minInvestment;
  /// @notice The maximum investment funds for purchasing tokens in USD
  uint256 public immutable maxInvestment;
  /// @notice The token used for pre-sale
  IERC20Metadata public immutable usdt;
  /// @dev The price feed address of native token
  AggregatorV2V3Interface internal immutable priceFeed;
  /// @notice The block timestamp after ending the presale purchasing
  uint256 public immutable notAfterBlock;

  constructor(
    address _usdt,
    address _priceFeed,
    uint256 _minInvestment,
    uint256 _maxInvestment,
    uint256 _notAfterBlock
  ) {
    require(
      _usdt != address(0) && _priceFeed != address(0),
      "invalid contract address"
    ); // ICA
    require(
      _minInvestment < _maxInvestment, 
      "invalid investment amount"
    );
    require(
      _notAfterBlock > block.timestamp,
      "invalid presale schedule"
    ); // IPS
    usdt = IERC20Metadata(_usdt);
    priceFeed = AggregatorV2V3Interface(_priceFeed);
    minInvestment = _minInvestment;
    maxInvestment = _maxInvestment;
    notAfterBlock = _notAfterBlock;
  }

  receive() external payable {}

  function order(string memory selendraAddress, uint amount) external inSalePeriod {
    require(amount > 0, "invalid token amount"); // ITA
    AggregatorV2V3Interface _priceFeed = priceFeed;
    int256 price = _priceFeed.latestAnswer();
    uint256 amountInUsd = amount.mul(uint256(price)).div(
      10**(usdt.decimals() + _priceFeed.decimals())
    );

    require(
      amountInUsd >= minInvestment,
      "the investment amount does not reach the minimum amount required"
    ); // LMI
    require(
      amountInUsd <= maxInvestment,
      "the investment amount exceed the maximum amount required"
    ); // LMI

    uint256 orderId = orders.length;
    uint256 selendraAmount = amountInUsd.mul(10**22).div(300); // 300 = 0.03(default price) * 10^4, 22 = 18(token decimals) + 4
    orders.push(OrderInfo({
      senderAddress: msg.sender,
      selendraAddress: selendraAddress,
      amount: selendraAmount
    }));
    balanceOf[msg.sender] = balanceOf[msg.sender].add(selendraAmount);
    usdt.safeTransferFrom(
      msg.sender,
      address(this),
      amount
    );

    emit TokenOrdered(orderId, msg.sender, selendraAddress, selendraAmount);
  }

  function claim() external onlyOwner afterSalePeriod {
    uint256 amountBnb = address(this).balance;
    uint256 amountUsdt = usdt.balanceOf(address(this));
    payable(msg.sender).transfer(amountBnb);
    usdt.transfer(msg.sender, amountUsdt);
  }

  modifier inSalePeriod() {
    require(block.timestamp <= notAfterBlock, "sale has already ended"); // PEN
    _;
  }

  modifier afterSalePeriod() {
    require(block.timestamp > notAfterBlock, "sale is still ongoing"); // PNE
    _;
  }
}