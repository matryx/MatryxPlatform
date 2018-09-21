pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./LibGlobals.sol";

import "./MatryxPlatform.sol";
import "./MatryxTrinity.sol";
import "./MatryxRound.sol";

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
    function getContributors() external view returns (address[]);
    function getContributorDistribution() external view returns(uint128[]);
    function getReferences() external view returns (address[]);
    function getTimeSubmitted() external view returns (uint256);
    function getTimeUpdated() external view returns (uint256);
    function getDetails() external view returns (LibSubmission.SubmissionDetails);
    function getBalance() external view returns (uint256);

    function updateDetails(LibSubmission.DetailsUpdates) external;
    function updateContributors(address[], uint128[], address[]) external;
    function updateReferences(address[], address[]) external;
}

library LibSubmission {

    struct SubmissionInfo {
        address owner;
        address tournament;
        address round;
        uint256 timeSubmitted;
        uint256 timeUpdated;
        uint256 reward;
    }

    // All information needed for creation of Submission
    struct SubmissionDetails {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        address[] contributors;
        uint128[] contributorDistribution;
        address[] references;
    }
    // bytes32[2] publicKey;
    // bytes32    privateKey;

    struct DetailsUpdates {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
    }

    // All state data and details of Submission
    struct SubmissionData {
        SubmissionInfo info;
        SubmissionDetails details;
        address[] allPermittedToView;
        mapping(address=>bool) permittedToView;
    }

    function onlyCanView(address self, address sender, MatryxPlatform.Data storage data) internal {
        require(data.submissions[self].permittedToView[sender]);
    }

    function onlyOwner(address self, address sender, MatryxPlatform.Data storage data) internal {
        require(data.submissions[self].info.owner == sender, "Must be owner");
    }

    function duringOpenSubmission(address self, MatryxPlatform.Data storage data) internal {
        address round = data.submissions[self].info.round;
        require(IMatryxRound(round).getState() == uint256(LibGlobals.RoundState.Open), "Must be open Round");
    }

    /// @dev Returns the Tournament address of this Submission
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        address round = data.submissions[self].info.round;
        return data.rounds[round].tournament;
    }

    /// @dev Returns the Round address of this Submission
    function getRound(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].info.round;
    }

    /// @dev Returns the title of this Submission
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.submissions[self].details.title;
    }

    /// @dev Returns the description hash of this Submission
    function getDescriptionHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        onlyCanView(self, sender, data);
        return data.submissions[self].details.descHash;
    }

    /// @dev Returns the file hash of this Submission
    function getFileHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        onlyCanView(self, sender, data);
        return data.submissions[self].details.fileHash;
    }

    /// @dev Returns the contributors of this Submission
    function getContributors(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].details.contributors;
    }

    function getContributorDistribution(address self, address, MatryxPlatform.Data storage data) external view returns(uint128[]) {
        return data.submissions[self].details.contributorDistribution;
    }

    /// @dev Returns the references of this Submission
    function getReferences(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].details.references;
    }

    /// @dev Returns the time this Submission was submitted
    function getTimeSubmitted(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.timeSubmitted;
    }

    /// @dev Returns the time this Submission was last updated
    function getTimeUpdated(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.timeUpdated;
    }

    /// @dev Returns the data struct of this Submission
    // function getDetails(address self, address, MatryxPlatform.Data storage data) public view returns (LibSubmission.SubmissionDetails) {
    //     return data.submissions[self];
    // }

    /// @dev Returns the MTX balance of this Submission
    function getBalance(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self);
    }

    /// @dev Updates the details of this Submission
    /// @param self     Address of this Submission
    /// @param data     Data struct on Platform
    /// @param updates  Details updates (title, descHash, fileHash)
    function updateDetails(address self, address sender, MatryxPlatform.Data storage data, LibSubmission.DetailsUpdates updates) public {
        onlyOwner(self, sender, data);
        duringOpenSubmission(self, data);

        LibSubmission.SubmissionDetails storage details = data.submissions[self].details;

        if (updates.title[0] != 0) details.title = updates.title;
        if (updates.descHash[0] != 0) details.descHash = updates.descHash;
        if (updates.fileHash[0] != 0) details.fileHash = updates.fileHash;

        data.submissions[self].info.timeUpdated = now;
    }

    /// @dev Adds and removes contributors to this Submission
    /// @param self          Address of this Submission
    /// @param data          Data struct on Platform
    /// @param contribsToAdd Contributors to add
    /// @param contribDist   Distribution of potential MTX reward for each contributor
    function updateContributors(address self, address sender, MatryxPlatform.Data storage data, address[] contribsToAdd, uint128[] contribDist, address[] contribsToRemove) public {
        require(contribsToAdd.length == contribDist.length, "Must include distribution for each contributor");

        onlyOwner(self, sender, data);
        duringOpenSubmission(self, data);

        address[] storage contribs = data.submissions[self].details.contributors;
        uint256 contribsLen = contribs.length;

        for (uint256 i = 0; i < contribsToAdd.length; i++) {
            contribs.push(contribsToAdd[i]);
            data.submissions[self].details.contributorDistribution.push(contribDist[i]);
        }

        for (i = 0; i < contribsToRemove.length; i++) {
            for (uint256 j = 0; j < contribsLen; j++) {
                if (contribs[j] == contribsToRemove[j]) {
                    delete contribs[j];
                    delete data.submissions[self].details.contributorDistribution[j];
                    break;
                }
            }
        }

        data.submissions[self].info.timeUpdated = now;
    }

    /// @dev Adds and removes references to this Submission
    /// @param self          Address of this Submission
    /// @param data          Data struct on Platform
    /// @param refsToAdd     References to add
    /// @param refsToRemove  References to remove
    function updateReferences(address self, address sender, MatryxPlatform.Data storage data, address[] refsToAdd, address[] refsToRemove) public {
        onlyOwner(self, sender, data);
        duringOpenSubmission(self, data);

        address[] storage refs = data.submissions[self].details.references;
        uint256 refsLen = refs.length;

        for (uint256 i = 0; i < refsToAdd.length; i++) {
            refs.push(refsToAdd[i]);
        }

        for (i = 0; i < refsToRemove.length; i++) {
            for (uint256 j = 0; j < refsLen; j++) {
                if (refs[j] == refsToRemove[i]) {
                    delete refs[j];
                    break;
                }
            }
        }

        data.submissions[self].info.timeUpdated = now;
    }
}
