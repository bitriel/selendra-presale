// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

import "./interfaces/IERC20Metadata.sol";

contract SelendraSale is Ownable {
  using SafeMath for uint256;
  using Math for uint256;
  using SafeERC20 for IERC20Metadata;

  event TokenOrdered(uint256 id, address senderAddress, address tokenAddress, string selendraAddress, uint256 selendraAmount);

  struct TokenInfo {
    address priceFeed;
    uint8 decimals;
  }
  struct OrderInfo {
    address senderAddress;
    address tokenAddress;
    string selendraAddress;
    uint256 selendraAmount;
  }

  /// @dev balanceOf[investor] = balance
  mapping(address => uint256) public balanceOf;
  /// @dev supportedTokens[tokenAddress] = TokenInfo
  mapping(address => TokenInfo) public supportedTokens;
  /// @dev orders[orderId] = OrderInfo
  OrderInfo[] public orders;
  /// @notice The minimum investment funds per purchasing order tokens in USD
  uint256 public minInvestment;
  /// @notice The maximum investment funds per purchasing order tokens in USD
  uint256 public maxInvestment;
  /// @notice The price feed address of native token
  AggregatorV2V3Interface internal immutable priceFeed;
  /// @notice The block timestamp after ending the presale purchasing
  uint256 public immutable notAfterBlock;
  /// @notice The block timestamp when contract is deployed.
  uint256 public immutable deployedAt;
  /// @notice The interval when price is increasing in seconds
  uint32 public priceIncreaseInterval;
  /// @notice The starting price of token auction in `actual price * 10^4`
  uint32 public startingPriceX4;
  /// @notice The increasing price index per interval in `index * 10^4`
  uint32 public priceIncreaseIndexX4;
  /// @notice The maximum interval of price increasing
  uint32 public maxIncreaseInterval;

  constructor(
    address _priceFeed,
    uint256 _minInvestment,
    uint256 _maxInvestment,
    uint256 _notAfterBlock,
    uint32 _priceIncreaseInterval,
    uint32 _startingPriceX4,
    uint32 _priceIncreaseIndexX4,
    uint32 _maxIncreaseInterval
  ) {
    require(
      _minInvestment < _maxInvestment, 
      "invalid investment amount"
    );
    require(
      _notAfterBlock > block.timestamp,
      "invalid presale schedule"
    ); // IPS
    priceFeed = AggregatorV2V3Interface(_priceFeed);
    minInvestment = _minInvestment;
    maxInvestment = _maxInvestment;
    notAfterBlock = _notAfterBlock;
    deployedAt = block.timestamp;
    priceIncreaseInterval = _priceIncreaseInterval;
    startingPriceX4 = _startingPriceX4;
    priceIncreaseIndexX4 = _priceIncreaseIndexX4;
    maxIncreaseInterval = _maxIncreaseInterval;
  }

  function order(string memory selendraAddress) external payable {
    (, int256 price, uint8 amountDecimals, uint8 priceDecimals) = estimateReturn(address(0), msg.value);
    _order(address(0), amountDecimals, price, priceDecimals, selendraAddress, msg.value); 
  }

  function orderToken(address token, uint256 amount, string memory selendraAddress) external {
    (, int256 price, uint8 amountDecimals, uint8 priceDecimals) = estimateReturn(token, amount);
    IERC20Metadata(token).safeTransferFrom(msg.sender, address(this), amount);
    _order(token, amountDecimals, price, priceDecimals, selendraAddress, amount);
  }

  function _order(address token, uint8 amountDecimals, int256 price, uint8 priceDecimals, string memory selendraAddress, uint256 amount) private inSalePeriod {
    uint256 amountInUsd = amount.mul(uint256(price)).div(
      10**priceDecimals
    );

    require(
      amountInUsd >= minInvestment * 10**amountDecimals,
      "the investment amount does not reach the minimum amount required"
    ); // LMI
    require(
      amountInUsd <= maxInvestment * 10**amountDecimals,
      "the investment amount exceed the maximum amount required"
    ); // LMI

    uint256 orderId = orders.length;
    uint256 SELPrice = getSELPrice();
    uint256 selendraAmount = amountInUsd.mul(10**(22 - amountDecimals)).div(SELPrice); // 300 = 0.03(default price) * 10^4, 22 = 18(selendra token decimals) + 4
    orders.push(OrderInfo({
      senderAddress: msg.sender,
      tokenAddress: token,
      selendraAddress: selendraAddress,
      selendraAmount: selendraAmount
    }));
    balanceOf[msg.sender] = balanceOf[msg.sender].add(selendraAmount);

    emit TokenOrdered(orderId, msg.sender, token, selendraAddress, selendraAmount);
  }

  function claim() external onlyOwner afterSalePeriod {
    uint256 amountBnb = address(this).balance;
    payable(msg.sender).transfer(amountBnb);
  }

  function claim(address token) external onlyOwner afterSalePeriod isTokenSupported(token) {
    uint256 tokenAmount = IERC20Metadata(token).balanceOf(address(this));
    require(IERC20Metadata(token).transfer(payable(msg.sender), tokenAmount));
  }

  function setSupportedToken(address _token, address _priceFeed)
    external
    onlyOwner
    inSalePeriod
  {
    require(_token != address(0), "invalid token address"); // ITA
    require(_priceFeed != address(0), "invalid oracle price feed address"); // IOPA

    supportedTokens[_token].priceFeed = _priceFeed;
    supportedTokens[_token].decimals = AggregatorV2V3Interface(_priceFeed)
        .decimals();
  }

  function getPrice() public view returns(int256 price) {
    price = priceFeed.latestAnswer();
    return price;
  }

  function getPrice(address token) public view isTokenSupported(token) returns(int256 price) {
    price = AggregatorV2V3Interface(supportedTokens[token].priceFeed).latestAnswer();
    return price;
  }

  function getSELPrice() public view returns(uint256 price) {
    uint256 howManyInterval = block.timestamp.sub(deployedAt).div(priceIncreaseInterval).min(maxIncreaseInterval);
    return howManyInterval.mul(priceIncreaseIndexX4).add(startingPriceX4);
  }

  function estimateReturn(address token, uint256 amount) public view returns(uint256 selendraAmount, int256 price, uint8 amountDecimals, uint8 priceDecimals) {
    require(token == address(0) || _isTokenSupported(token), "token is not supported");

    if(token == address(0)) {
      price = getPrice();
      amountDecimals = 18;
      priceDecimals = priceFeed.decimals();
    } else {
      price = getPrice(token);
      amountDecimals = IERC20Metadata(token).decimals();
      priceDecimals = AggregatorV2V3Interface(supportedTokens[token].priceFeed).decimals();
    }

    // 300 = 0.03(default price) * 10^4, 22 = 18(token decimals) + 4
    uint256 SELPrice = getSELPrice();
    if(amountDecimals + priceDecimals >= 22) { 
      selendraAmount = amount.mul(uint256(price)).div(SELPrice * 10**(amountDecimals + priceDecimals - 22)); 
    } else {
      selendraAmount = amount.mul(uint256(price).mul(10**(22 - (amountDecimals + priceDecimals)))).div(SELPrice); 
    }
  }

  function setMinInvestment(uint256 amount) 
    external
    onlyOwner
    inSalePeriod 
  {
    require(amount < maxInvestment, "invalid minimum investment.");
    minInvestment = amount;
  }

  function setMaxInvestment(uint256 amount) 
    external
    onlyOwner
    inSalePeriod 
  {
    require(amount > minInvestment, "invalid maximum investment.");
    maxInvestment = amount;
  }

  function setPriceIncreaseIndex(uint32 index) 
    external
    onlyOwner
    inSalePeriod 
  {
    priceIncreaseIndexX4 = index;
  }

  function setPriceIncreaseInterval(uint32 interval) 
    external
    onlyOwner
    inSalePeriod 
  {
    priceIncreaseInterval = interval;
  }

  function setMaxIncreaseInterval(uint32 interval) 
    external
    onlyOwner
    inSalePeriod 
  {
    maxIncreaseInterval = interval;
  }

  modifier inSalePeriod() {
    require(block.timestamp <= notAfterBlock, "sale has already ended"); // PEN
    _;
  }

  modifier afterSalePeriod() {
    require(block.timestamp > notAfterBlock, "sale is still ongoing"); // PNE
    _;
  }

  function _isTokenSupported(address token) private view returns(bool isTrue) {
    return supportedTokens[token].priceFeed != address(0);
  }

  modifier isTokenSupported(address token) {
    require(_isTokenSupported(token), "token is not supported");
    _;
  }
}