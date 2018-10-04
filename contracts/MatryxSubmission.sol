pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxTrinity.sol";
import "./MatryxRound.sol";

contract MatryxSubmission is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxSubmission {
    function transferFrom(address, address, uint256) external;
    function transferTo(address, address, uint256) external;
    function setInfo(MatryxTrinity.Info) external;

    function getTournament() external view returns (address);
    function getRound() external view returns (address);

    function getOwner() external view returns (address);
    function getTitle() external view returns (bytes32[3]);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);
    function getDistribution() external view returns(uint256[]);
    function getContributors() external view returns (address[]);
    function getReferences() external view returns (address[]);
    function getTimeSubmitted() external view returns (uint256);
    function getTimeUpdated() external view returns (uint256);
    function getViewers() external view returns (address[]);
    function getBalance() external view returns (uint256);
    function getTotalWinnings() external view returns (uint256);
    function getData() external view returns (LibSubmission.SubmissionReturnData);

    function unlockFile() external;
    function updateDetails(LibSubmission.DetailsUpdates) external;
    function setContributorsAndReferences(LibGlobals.IndexedAddresses, uint256[], LibGlobals.IndexedAddresses) external;

    function getAvailableReward() external view returns (uint256);
    function withdrawReward() external;
}

library LibSubmission {
    using SafeMath for uint256;

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
        uint256[] distribution;
        address[] contributors;
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
        mapping(address=>uint256) amountWithdrawn;
        address[] referencedIn;
    }

    // everything but the mappings
    struct SubmissionReturnData {
        SubmissionInfo info;
        SubmissionDetails details;
    }

    function onlyOwner(address self, address sender, MatryxPlatform.Data storage data) internal view {
        require(data.submissions[self].info.owner == sender, "Must be owner");
    }

    function duringOpenSubmission(address self, MatryxPlatform.Data storage data) internal view {
        address round = data.submissions[self].info.round;
        require(IMatryxRound(round).getState() == uint256(LibGlobals.RoundState.Open), "Must be open Round");
    }

    /// @dev Returns the Tournament address of this Submission
    function getTournament(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        address round = data.submissions[self].info.round;
        return data.rounds[round].info.tournament;
    }

    /// @dev Returns the Round address of this Submission
    function getRound(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].info.round;
    }

    /// @dev Returns the owner of this Submission
    function getOwner(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.submissions[self].info.owner;
    }

    /// @dev Returns the title of this Submission
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.submissions[self].details.title;
    }

    /// @dev Returns the description hash of this Submission
    function getDescriptionHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.submissions[self].details.descHash;
    }

    /// @dev Returns the file hash of this Submission
    function getFileHash(address self, address sender, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        bool canView = data.submissions[self].permittedToView[sender];
        bytes32[2] memory empty;

        return canView ? data.submissions[self].details.fileHash : empty;
    }

    /// @dev Returns the reward distribution of this Submission
    function getDistribution(address self, address, MatryxPlatform.Data storage data) external view returns (uint256[]) {
        return data.submissions[self].details.distribution;
    }

    /// @dev Returns the contributors of this Submission
    function getContributors(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].details.contributors;
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

    function getViewers(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].allPermittedToView;
    }

    /// @dev Returns the MTX balance of this Submission
    function getBalance(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self);
    }

    /// @dev Returns the total winnings of this Submission
    function getTotalWinnings(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.reward;
    }

    // /// @dev Returns the data struct of this Submission
    // function getDetails(address self, address, MatryxPlatform.Data storage data) public view returns (LibSubmission.SubmissionDetails) {
    //     return data.submissions[self].details;
    // }

    /// @dev Returns all information of this Submission
    function getData(address self, address sender, MatryxPlatform.Data storage data) public view returns (LibSubmission.SubmissionReturnData) {
        SubmissionReturnData memory sub;
        sub.info = data.submissions[self].info;
        sub.details = data.submissions[self].details;

        if (!data.submissions[self].permittedToView[sender]) {
            sub.details.fileHash[0] = 0x0;
            sub.details.fileHash[1] = 0x0;
        }

        return sub;
    }

    /// @dev Unlocks the descHash and fileHash for sender
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    function unlockFile(address self, address sender, MatryxPlatform.Data storage data) public {
        require(data.users[sender].exists, "Must have entered Matryx");
        LibSubmission.SubmissionData storage submission = data.submissions[self];

        require(!submission.permittedToView[sender], "Already permitted to view");

        if (IMatryxRound(submission.info.round).getState() < uint256(LibGlobals.RoundState.InReview)) {
            bool isContributor = false;
            for (uint256 i = 0; i < submission.details.contributors.length; i++) {
                if (submission.details.contributors[i] == sender) {
                    isContributor = true;
                    break;
                }
            }
            require(isContributor, "Must be contributor to unlock before review");
        }

        submission.permittedToView[sender] = true;
        submission.allPermittedToView.push(sender);
        data.users[sender].unlockedFiles.push(self);
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

    /// @dev Adds and removes contributors and references on this Submission
    /// @param self          Address of this Submission
    /// @param sender        msg.sender to this Submission
    /// @param info          Info struct on Platform
    /// @param data          Data struct on Platform
    /// @param contribs      Contributor addresses and indices for modifying Submission's contributors
    /// @param distribution  Distribution of credit to Submission's contributors
    /// @param refs          Reference address and indices for modifying Submission's references
    function setContributorsAndReferences(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibGlobals.IndexedAddresses contribs, uint256[] distribution, LibGlobals.IndexedAddresses refs) public {
        onlyOwner(self, sender, data);

        require(contribs.addresses.length == distribution.length, "Must include distribution for each contributor");

        address LibUtils = MatryxSystem(info.system).getContract(info.version, "LibUtils");
        LibSubmission.SubmissionDetails storage details = data.submissions[self].details;

        for (uint256 i = 0; i < contribs.indices.length; i++) {
            uint256 index = contribs.indices[i];

            if (contribs.addresses[i] != 0x0) {
                details.contributors[index] = contribs.addresses[i];
                details.distribution[index + 1] = distribution[i];
            }

            else {
                assembly {
                    let offset := 0x100000000000000000000000000000000000000000000000000000000
                    let ptr := mload(0x40)

                    mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                    mstore(add(ptr, 0x04), add(details_slot, 8))                // arg 0 - details.contributors
                    mstore(add(ptr, 0x24), index)                               // arg 1 - index

                    let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                    if iszero(res) { revert(0, 0) }                             // safety check

                    mstore(add(ptr, 0x04), add(details_slot, 7))                // arg 0 - details.distribution
                    mstore(add(ptr, 0x24), add(index, 1))                       // arg 1 - index

                    res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)         // call LibUtils.removeArrayElement
                    if iszero(res) { revert(0, 0) }                             // safety check
                }
            }
        }

        if (contribs.addresses.length > contribs.indices.length) {
            for (i = contribs.indices.length; i < contribs.addresses.length; i++) {
                details.contributors.push(contribs.addresses[i]);
                details.distribution.push(distribution[i]);
            }
        }

        for (i = 0; i < refs.indices.length; i++) {
            index = refs.indices[i];

            if (refs.addresses[i] != 0x0) {
                details.references[index] = refs.addresses[i];
            }

            else {
                assembly {
                    let offset := 0x100000000000000000000000000000000000000000000000000000000
                    let ptr := mload(0x40)

                    mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                    mstore(add(ptr, 0x04), add(details_slot, 9))                // arg 0 - details.references
                    mstore(add(ptr, 0x24), index)                               // arg 1 - index

                    let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                    if iszero(res) { revert(0, 0) }                             // safety check
                }
            }
        }

        if (refs.addresses.length > refs.indices.length) {
            for (i = refs.indices.length; i < refs.addresses.length; i++) {
                details.references.push(refs.addresses[i]);
            }
        }
    }

    /// @dev Get the reward available to the caller on this Submissions
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    /// @return        Amount of MTX available to msg.sender
    function getAvailableReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        LibSubmission.SubmissionData storage submission = data.submissions[self];
        uint256[] storage distribution = submission.details.distribution;

        uint256 contributorIndex = 0;
        uint256 totalRefShare;
        uint256 share;

        uint256 distTotal = distribution[0];
        for (uint256 i = 1; i < distribution.length; i++) {
            distTotal = distTotal.add(distribution[i]);

            if (submission.details.contributors[i - 1] == sender) {
                contributorIndex = i;
            }
        }

        uint256 reward = submission.info.reward;
        if (submission.details.references.length > 0) {
            totalRefShare = reward.mul(10**18).div(10**19); // 10%
            reward = reward - totalRefShare;

            for (i = 0; i < submission.details.references.length; i++) {
                address ref = submission.details.references[i];
                if (sender != ref) continue;

                share = totalRefShare.mul(10**18).div(submission.details.references.length).div(10**18);
                share = share.sub(submission.amountWithdrawn[ref]);

                return share;
            }
        }

        if (contributorIndex == 0) {
            if (sender != submission.info.owner) return 0;
        }

        share = reward.mul(10**18).mul(distribution[contributorIndex]).div(distTotal).div(10**18);
        share = share.sub(submission.amountWithdrawn[sender]);

        return share;
    }

    /// @dev Allows the owner and contributors to this Submission to withdraw from this Submission
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function withdrawReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibSubmission.SubmissionData storage submission = data.submissions[self];
        uint256 share;

        // if owner, transfer 10% to references
        if (sender == submission.info.owner) {
            for (uint256 i = 0; i < submission.details.references.length; i++) {
                address ref = submission.details.references[i];
                share = getAvailableReward(self, ref, info, data);

                IMatryxSubmission(self).transferTo(info.token, ref, share);
                submission.amountWithdrawn[ref] = submission.amountWithdrawn[ref].add(share);
                data.submissions[ref].info.reward = data.submissions[ref].info.reward.add(share);
            }
        }

        share = getAvailableReward(self, sender, info, data);
        require(share > 0, "Already withdrawn full amount");

        IMatryxSubmission(self).transferTo(info.token, sender, share);
        submission.amountWithdrawn[sender] = submission.amountWithdrawn[sender].add(share);
        data.users[sender].totalWinnings = data.users[sender].totalWinnings.add(share);
    }
}
