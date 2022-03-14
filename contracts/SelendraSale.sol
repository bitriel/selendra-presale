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
  uint256 public immutable minInvestment;
  /// @notice The maximum investment funds per purchasing order tokens in USD
  uint256 public immutable maxInvestment;
  /// @dev The price feed address of native token
  AggregatorV2V3Interface internal immutable priceFeed;
  /// @notice The block timestamp after ending the presale purchasing
  uint256 public immutable notAfterBlock;

  constructor(
    address _priceFeed,
    uint256 _minInvestment,
    uint256 _maxInvestment,
    uint256 _notAfterBlock
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
  }

  function order(string memory selendraAddress) external payable {
    int256 price = getPrice();
    _order(address(0), 18, price, priceFeed.decimals(), selendraAddress, msg.value); 
  }

  function order(address token, uint256 amount, string memory selendraAddress) external isTokenSupported(token) {
    int256 price = getPrice(token);
    uint8 amountDecimals = IERC20Metadata(token).decimals();
    uint8 priceDecimals = supportedTokens[token].decimals;
    IERC20Metadata(token).safeTransferFrom(msg.sender, address(this), amount);
    _order(token, amountDecimals, price, priceDecimals, selendraAddress, amount);
  }

  function _order(address token, uint8 amountDecimals, int256 price, uint8 priceDecimals, string memory selendraAddress, uint256 amount) private inSalePeriod {
    uint256 amountInUsd = amount.mul(uint256(price)).div(
      10**(amountDecimals + priceDecimals)
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
  }

  function getPrice(address token) public view isTokenSupported(token) returns (int256 price) {
    price = AggregatorV2V3Interface(supportedTokens[token].priceFeed).latestAnswer();
  }

  modifier inSalePeriod() {
    require(block.timestamp <= notAfterBlock, "sale has already ended"); // PEN
    _;
  }

  modifier afterSalePeriod() {
    require(block.timestamp > notAfterBlock, "sale is still ongoing"); // PNE
    _;
  }

  modifier isTokenSupported(address token) {
    require(supportedTokens[token].priceFeed != address(0), "token is not supported");
    _;
  }
}