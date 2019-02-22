pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface ITournamentUpgraded {
    function getBalance() external pure returns (uint256);
}

library LibTournamentUpgraded {
    function getBalance(address self, address, MatryxPlatform.Data storage) public pure returns (uint256) {
        return 99000000000000000000;
    }
}