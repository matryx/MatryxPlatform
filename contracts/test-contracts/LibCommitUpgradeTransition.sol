pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "../MatryxSystem.sol";
import "../MatryxPlatform.sol";

library LibCommitUpgradeTransition {

    struct NewCommit
    {
        address owner;
        uint256 timestamp;
        bytes32 groupHash;
        bytes32 commitHash;
        string content;
        uint256 value;
        uint256 ownerTotalValue;
        uint256 totalValue;
        uint256 height;
        bytes32 parentHash;
        bytes32[] children;
        uint256 upgradeVersion;
    }

    function upgradeCommitAndAncestry(address self, address sender, MatryxPlatform.Data storage data, bytes32 commitHash) public {
        LibCommit.Commit storage commit = data.commits[commitHash];
        require(sender == commit.owner, "Must own commit to upgrade");

        bytes32 loopHash = commitHash;
        for (uint256 i = commit.height; i > 0; i--) {

            LibCommit.Commit storage commit = data.commits[loopHash];
            // set upgradeVersion to 1
            assembly { sstore(add(commit_slot, 11), 1) }

            loopHash = data.commits[loopHash].parentHash;
        }
    }
}
