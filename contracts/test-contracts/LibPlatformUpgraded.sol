pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface IPlatformUpgraded {
    function getTwo() external pure returns (uint256);
    function getBalanceOf(address user) external pure returns (uint256);
}

library LibPlatformUpgraded {
    function getTwo(address, address, MatryxPlatform.Info storage) public pure returns (uint256 number) {
        return 2;
    }

    function getBalanceOf(address, address, MatryxPlatform.Data storage, address) public pure returns (uint256 balance) {
        return 99000000000000000000;
    }
}