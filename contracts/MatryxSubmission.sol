pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxForwarder.sol";

import "./MatryxPlatform.sol";

contract MatryxSubmission is MatryxForwarder {
    constructor (uint256 _version, address _proxy) MatryxForwarder(_version, _proxy) public {}
}

interface IMatryxSubmission {
    function getTournament() external view returns (address);
    function getRound() external view returns (address);

    function getTitle() external view returns (bytes32[3]);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);

    function getData() external view returns (LibSubmission.SubmissionData);
}

library LibSubmission {
    // All information needed for creation of Submission
    struct SubmissionDetails {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
    }

    // All state data and details of Submission
    struct SubmissionData {
        address tournament;
        address round;
        SubmissionDetails details;
        uint256 timeSubmitted;
        uint256 timeUpdated;
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
}
