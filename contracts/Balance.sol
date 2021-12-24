// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

contract Balance {
    function balance(address con) external view returns(uint256) {
        return con.balance;
    }
}