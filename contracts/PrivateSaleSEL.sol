// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IPreIDOBase.sol";

contract PrivateSaleSEL is IPreIDOBase, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    struct OrderInfo {
        address payable beneficiary;
        uint256 amount;
        uint256 releaseOnBlock;
        bool claimed;
    }

    /// @dev the default lock duration for private sale
    uint256 public constant LOCK_DURATION = 180 days; // 180 days = 6 months;
    /// @dev the default token price for private sale in 4 decimals
    // uint256 public constant TOKEN_PRICEX4 = 165; // // 165 = 0.0165 * 10^4
    /// @dev balanceOf[investor] = balance
    mapping(address => uint256) public override balanceOf;
    /// @dev orderIds[investor] = array of order ids
    mapping(address => uint256[]) private orderIds;
    /// @dev orders[orderId] = OrderInfo
    mapping(uint256 => OrderInfo) public override orders;
    /// @dev The latest order id for tracking order info
    uint256 public orderCount;

    receive() external payable {}

    function initialize() external initializer {
        __Ownable_init();
        orderCount = 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function investorOrderIds(address investor)
        external
        view
        override
        returns (uint256[] memory ids)
    {
        uint256[] memory arr = orderIds[investor];
        return arr;
    }

    function order(address payable recipient) external payable onlyOwner {
        require(recipient != address(0), "invalid investor address"); // IIA
        require(msg.value > 0, "invalid token amount"); // ITA

        uint256 releaseOnBlock = block.timestamp.add(LOCK_DURATION);

        orders[++orderCount] = OrderInfo(
            recipient,
            msg.value,
            releaseOnBlock,
            false
        );
        balanceOf[recipient] = balanceOf[recipient].add(msg.value);
        orderIds[recipient].push(orderCount);

        emit LockTokens(
            recipient,
            orderCount,
            msg.value,
            block.timestamp,
            releaseOnBlock
        );
    }

    function redeem(uint256 orderId) external {
        require(orderId <= orderCount, "the order ID is incorrect"); // IOI

        OrderInfo storage orderInfo = orders[orderId];
        require(
            _msgSender() == orderInfo.beneficiary || _msgSender() == owner(),
            "not order beneficiary or owner of contract"
        ); // NOO
        require(
            block.timestamp >= orderInfo.releaseOnBlock,
            "tokens are being locked"
        ); // TIL
        require(!orderInfo.claimed, "tokens are ready to be claimed"); // TAC

        orderInfo.beneficiary.transfer(orderInfo.amount);
        orderInfo.claimed = true;
        balanceOf[orderInfo.beneficiary] = balanceOf[orderInfo.beneficiary].sub(
            orderInfo.amount
        );

        emit UnlockTokens(orderInfo.beneficiary, orderId, orderInfo.amount);
    }
}
