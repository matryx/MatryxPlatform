pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface ICommitUpgraded {
    function getAvailableRewardForUser(bytes32, address) external pure returns (uint256);
}

library LibCommitUpgraded {
    function getAvailableRewardForUser(address self, address, MatryxPlatform.Data storage, bytes32 commitHash, address user) public pure returns (uint256) {
        return 42;
    }
}
