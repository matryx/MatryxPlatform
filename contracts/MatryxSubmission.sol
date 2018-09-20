pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxTrinity.sol";

import "./MatryxPlatform.sol";

contract MatryxSubmission is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxSubmission {
    function transferFrom(address, address, uint256) external;
    function transferTo(address, address, uint256) external;

    function getTournament() external view returns (address);
    function getRound() external view returns (address);

    function getTitle() external view returns (bytes32[3]);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);

    function getData() external view returns (LibSubmission.SubmissionData);

    function getBalance() external view returns (uint256);
}

library LibSubmission {
    // All information needed for creation of Submission
    struct SubmissionDetails {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
    }
    // bytes32[2] publicKey;
    // bytes32    privateKey;

    // All state data and details of Submission
    struct SubmissionData {
        address owner;
        address tournament;
        address round;
        SubmissionDetails details;
        uint256 timeSubmitted;
        uint256 timeUpdated;
        uint256 reward;
    }

    /// @dev Returns the Tournament address of this Submission
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        address round = data.submissions[self].round;
        return data.rounds[round].tournament;
    }

    /// @dev Returns the Round address of this Submission
    function getRound(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].round;
    }

    /// @dev Returns the title of this Submission
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.submissions[self].details.title;
    }

    /// @dev Returns the description hash of this Submission
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.submissions[self].details.descHash;
    }

    /// @dev Returns the file hash of this Submission
    function getFileHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.submissions[self].details.fileHash;
    }

    /// @dev Returns the data struct of this Submission
    function getData(address self, address, MatryxPlatform.Data storage data) public view returns (LibSubmission.SubmissionData) {
        return data.submissions[self];
    }

    /// @dev Returns the MTX balance of this Submission
    function getBalance(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self);
    }
}
