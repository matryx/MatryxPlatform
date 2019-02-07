pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface IPlatformUpgraded {
    function getTwo() external view returns (uint256);
    function getBalanceOf(address user) external returns (uint256);
}

library LibPlatformUpgraded {
    function getTwo(address self, address sender, MatryxPlatform.Info storage info) public view returns (uint256 number) {
        return 2;
    }

    function getBalanceOf(address self, address sender, MatryxPlatform.Data storage data, address user) public view returns (uint256 balance) {
        return 99000000000000000000;
    }
}
