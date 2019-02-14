pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxPlatform.sol";

interface IMatryxCommitUpgraded {
    function getGroupMembers(bytes32 commitHash) external pure returns (address[] memory);
}

library LibCommitUpgraded {
    function getGroupMembers(address self, address, MatryxPlatform.Data storage, bytes32) public pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = self;
        return array;
    }
}
