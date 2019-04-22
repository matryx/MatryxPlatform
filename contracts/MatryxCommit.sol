pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibCommit.sol";
import "./MatryxForwarder.sol";

contract MatryxCommit is MatryxForwarder {
    constructor (uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxCommit {
    function getCommit(bytes32 commitHash) external view returns (LibCommit.Commit memory commit);
    function getBalance(bytes32 commitHash) external view returns (uint256);
    function getCommitByContent(string calldata content) external view returns (LibCommit.Commit memory commit);
    function getGroupMembers(bytes32 commitHash) external view returns (address[] memory);
    function getSubmissionsForCommit(bytes32 commitHash) external view returns (bytes32[] memory);

    function addGroupMember(bytes32 commitHash, address member) external;
    function addGroupMembers(bytes32 commitHash, address[] calldata members) external;
    function claimCommit(bytes32 commitHash) external;
    function createCommit(bytes32 parentHash, bool isFork, bytes32 salt, string calldata content, uint256 value) external;
    function createSubmission(address tAddress, string calldata content, bytes32 parentHash, bool isFork, bytes32 salt, string calldata commitContent, uint256 value) external;
    function getAvailableRewardForUser(bytes32 commitHash, address user) external view returns (uint256);
    function withdrawAvailableReward(bytes32 commitHash) external;
}
