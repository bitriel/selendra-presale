// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

/// @title Pre-IDO state that can change
/// @notice These methods compose the Pre-IDO's state, and can change with any frequency including multiple times
/// per transaction
interface IPreIDOState {
  /// @notice Look up information about a specific order in the pre-IDO contract
  /// @param id The order ID to look up
  /// @return beneficiary The investor address whose `amount` of tokens in this order belong to,
  /// amount The amount of tokens has been locked in this order,
  /// releaseOnBlock The block number when tokens can be redeem or claimed from the time-locked contract,
  /// claimed The status of this order whether it's claimed or not.
  function orders(uint256 id) external view returns(
    address beneficiary,
    uint256 amount,
    uint256 releaseOnBlock,
    bool claimed
  );
}