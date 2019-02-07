pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface IMatryxCommitUpgraded {
    function getGroupName(bytes32 groupHash) external view returns (string memory);
}

library LibCommitUpgraded {
    /// @dev Returns group name for given hash
    /// @param self       MatryxCommit address
    /// @param sender     msg.sender to the Platform
    /// @param data       Platform data struct
    /// @param groupHash  Hash of group name
    function getGroupName(address self, address sender, MatryxPlatform.Data storage data, bytes32 groupHash) public view returns (string memory) {
        return "tacotaco";
    }
}
