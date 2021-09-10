// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV2V3Interface.sol";

import "./interfaces/IERC20Metadata.sol";

contract Presale is Ownable{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC20Metadata;

  struct TokenInfo {
    address priceFeed;
    int256 rate;
    uint8 decimals;
    uint256 raisedAmount; // how many tokens has been raised so far
  }
  struct OrderInfo {
    address beneficiary;
    uint256 amount;
    uint256 releaseOnBlock;
    bool claimed;
  }

  uint256 private constant MIN_LOCK = 365 days;
  /// @dev discountsLock[rate] = durationInSeconds
  mapping(uint8 => uint256) public discountsLock;
  /// @dev supportedTokens[tokenAddress] = TokenInfo
  mapping(address => TokenInfo) public supportedTokens;
  // /// @dev contributedBalance[userAddress][tokenAddress] = balance
  // mapping(address => mapping(address => uint256)) public contributedBalance;
  /// @dev orders[orderId] = OrderInfo
  mapping(uint256 => OrderInfo) public orders;
  /// @dev The latest order id for tracking order info
  uint256 private latestOrderId = 0;
  /// @notice The total amount of tokens had been distributed 
  uint256 public totalDistributed;
  /// @notice The minimum investment funds for purchasing tokens in USD
  uint256 public minInvestment;
  /// @notice The token used for pre-sale
  IERC20Metadata public immutable token;
  /// @dev The price feed address of native token
  AggregatorV2V3Interface internal immutable priceFeed;
  /// @notice The block number before starting the presale purchasing
  uint256 public immutable notBeforeBlock;
  /// @notice The block number after ending the presale purchasing
  uint256 public immutable notAfterBlock;

  event LockFunds(address indexed sender, uint256 id, uint256 amount, uint256 lockOnBlock, uint256 releaseOnBlock);   
  event UnlockFunds(address indexed receiver, uint256 id, uint256 amount);

  constructor(address _token, address _priceFeed, uint256 _notBeforeBlock, uint256 _notAfterBlock) {
    require(_token != address(0) && _priceFeed != address(0), "ICA"); // invalid contract address
    require(_notBeforeBlock >= block.number && _notAfterBlock > _notBeforeBlock, "IPS"); // invalid presale schedule
    token = IERC20Metadata(_token);
    priceFeed = AggregatorV2V3Interface(_priceFeed);
    notBeforeBlock = _notBeforeBlock;
    notAfterBlock = _notAfterBlock;

    // initialize discounts rate lock duration
    discountsLock[10] = 12 minutes;
    // discountsLock[10] = MIN_LOCK;
    // discountsLock[20] = 2 * MIN_LOCK;
    // discountsLock[30] = 3 * MIN_LOCK;
  }

  function order(uint8 discountsRate) external payable inPresalePeriod {
    int256 price = getPrice();
    _order(msg.value, 18, price, priceFeed.decimals(), discountsRate);
  }

  function orderToken(address fundsAddress, uint256 fundsAmount, uint8 discountsRate) external inPresalePeriod {
    TokenInfo storage tokenInfo = supportedTokens[fundsAddress];
    require(fundsAmount > 0, "IV"); // invalid value
    require(tokenInfo.priceFeed != address(0), "FNS"); // the funds is not supported for purchase some token

    tokenInfo.rate = getPriceToken(fundsAddress);
    uint256 fundsAmountMargin = fundsAmount.add(fundsAmount.mul(10).div(100));
    IERC20(fundsAddress).safeApprove(address(this), fundsAmountMargin);
    IERC20(fundsAddress).safeTransferFrom(msg.sender, address(this), fundsAmount);
    tokenInfo.raisedAmount = tokenInfo.raisedAmount.add(fundsAmount);
    _order(fundsAmount, IERC20Metadata(fundsAddress).decimals(), tokenInfo.rate, tokenInfo.decimals, discountsRate);
  }

  function _order(uint amount, uint8 _amountDecimals, int256 price, uint8 _priceDecimals, uint8 discountsRate) internal {
    require(amount.mul(uint256(price)).div(10 ** (_amountDecimals + _priceDecimals)) >= minInvestment, "LMI"); // less than mininum investment
    ++latestOrderId;

    uint256 lockDuration = discountsLock[discountsRate];
    // require(lockDuration >= MIN_LOCK, "NDR");

    uint256 releaseOnBlock = block.number.add(lockDuration.div(3));
    uint256 tokenPriceX4 = 300 * (100 - discountsRate) / 100; // 300 = 0.03(default price) * 10^4
    uint256 distributeAmount = amount.mul(uint256(price)).div(tokenPriceX4);
    uint8 upperPow = token.decimals() + 4; // 4(token price decimals) => 10^4 = 22
    uint8 lowerPow = _amountDecimals + _priceDecimals;
    if(upperPow >= lowerPow) {
      distributeAmount = distributeAmount.mul(10 ** (upperPow - lowerPow));
    } else {
      distributeAmount = distributeAmount.div(10 ** (lowerPow - upperPow));
    }
    require(totalDistributed + distributeAmount <= token.balanceOf(address(this)), "NET"); // not enough supply tokens to be distributed

    orders[latestOrderId] = OrderInfo(msg.sender, distributeAmount, releaseOnBlock, false);
    totalDistributed = totalDistributed.add(distributeAmount);

    emit LockFunds(msg.sender, latestOrderId, distributeAmount, block.number, releaseOnBlock);
  }

  function redeem(uint256 orderId) external {
    require(orderId <= latestOrderId, "IOI"); // incorrect order id
    OrderInfo storage orderInfo = orders[orderId];
    require(msg.sender == orderInfo.beneficiary, "NOO"); // not order beneficiary
    require(orderInfo.amount > 0, "ITA"); // insufficient token amount to redeem
    require(block.number >= orderInfo.releaseOnBlock, "TIL"); // tokens is still in locked
    require(!orderInfo.claimed, "TAC"); // tokens is already claimed

    uint256 amount = safeTransferToken(orderInfo.beneficiary, orderInfo.amount);
    orderInfo.claimed = true;
    emit UnlockFunds(orderInfo.beneficiary, orderId, amount);
  }

  function getPrice() public view inPresalePeriod returns(int256 price) {
    price = priceFeed.latestAnswer();
  }

  function getPriceToken(address fundAddress) public view inPresalePeriod returns(int256 price) {
    price = AggregatorV2V3Interface(supportedTokens[fundAddress].priceFeed).latestAnswer();
  }

  function remainingTokens() public view inPresalePeriod returns(uint256 remainingToken) {
    remainingToken = token.balanceOf(address(this)) - totalDistributed;
  }

  function collectFunds(address fundsAddress) external onlyOwner afterPresalePeriod {
    uint256 amount = IERC20(fundsAddress).balanceOf(address(this));
    require(amount > 0, "NEC"); // not enough to collect
    IERC20(fundsAddress).transfer(msg.sender, amount);
  }

  function collect() external onlyOwner afterPresalePeriod {
    uint256 amount = address(this).balance;
    require(amount > 0, "NEC"); // not enough to collect
    payable(msg.sender).transfer(amount);
  }

  function rewardRemainingTokens(address _to, uint256 _amount) public onlyOwner afterPresalePeriod {
    require(_to != address(0), "IAA"); // invalid account address
    require(_amount > 0, "IAV"); // invalid amount value
    
    uint256 amount = safeTransferToken(_to, _amount);
    totalDistributed = totalDistributed.add(amount);
  }

  function setMinInvestment(uint256 _minInvestment) external onlyOwner beforePresaleEnd {
    require(_minInvestment > 0, "IV"); // Invalid value
    minInvestment = _minInvestment;
  }

  function setSupportedToken(address _token, address _priceFeed) external onlyOwner beforePresaleEnd {
    require(_token != address(0), "ITA"); // invalid token address
    require(_priceFeed != address(0), "IOPA"); // invalid oracle price feed address

    supportedTokens[_token].priceFeed = _priceFeed;
    supportedTokens[_token].decimals = AggregatorV2V3Interface(_priceFeed).decimals();
    supportedTokens[_token].rate = AggregatorV2V3Interface(_priceFeed).latestAnswer();
  }

  function safeTransferToken(address _to, uint256 _amount) internal returns(uint256 amount) {
    uint256 bal = token.balanceOf(address(this));
    if(bal < _amount) {
      token.safeTransfer(_to, bal);
      amount = bal;
    } else {
      token.safeTransfer(_to, _amount);
      amount = _amount;
    }
  }

  modifier inPresalePeriod {
    require(block.number > notBeforeBlock, "PNS"); // Pre-sale not yet start
    require(block.number < notAfterBlock, "PEN"); // Pre-sale is end now
    _;
  }

  modifier afterPresalePeriod {
    require(block.number > notAfterBlock, "PNE"); // Pre-sale is not yet end
    _;
  }

  modifier beforePresaleEnd {
    require(block.number < notAfterBlock, "PEN"); // Pre-sale is end now
    _;
  }
}