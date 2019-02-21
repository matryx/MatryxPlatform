pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface IPlatformUpgraded {
    function getTwo() external pure returns (uint256);
    function getTournamentCount() external pure returns (uint256);
}

library LibPlatformUpgraded {
    function getTwo(address, address, MatryxPlatform.Info storage) public pure returns (uint256 number) {
        return 2;
    }

    function getTournamentCount(address, address, MatryxPlatform.Data storage) public pure returns (uint256 count) {
        return 99000000000000000000;
    }
}