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

    function getVersion() external view returns (uint256);
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
    function getReward() external view returns (uint256);
    function getReferencedIn() external view returns (address[]);
    function getVotes() external view returns (uint256, uint256);
    function getViewers() external view returns (address[]);
    function getBalance() external view returns (uint256);
    function getTotalWinnings() external view returns (uint256);
    function getData() external view returns (LibSubmission.SubmissionReturnData);

    function unlockFile() external;
    function updateDetails(LibSubmission.DetailsUpdates) external;
    function addContributorsAndReferences(address[], uint256[], address[]) external;
    function removeContributorsAndReferences(address[], address[]) external;
    function flagMissingReference(address) external;

    function getAvailableReward() external view returns (uint256);
    function withdrawReward() external;
}

library LibSubmission {
    using SafeMath for uint256;

    struct SubmissionInfo {
        uint256 version;
        address owner;
        address tournament;
        address round;
        uint256 timeSubmitted;
        uint256 timeUpdated;
        uint256 reward;
        address[] referencedIn;
        uint256 positiveVotes;
        uint256 negativeVotes;
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
        mapping(address=>uint256) availableReward;
        uint256 totalAllocated;
        address[] missingReferences;
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

    /// @dev Returns the version of this Submission
    function getVersion(address self, address, MatryxPlatform.Data storage data) external view returns (uint256) {
        return data.submissions[self].info.version;
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
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
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

    /// @dev Returns this Submission's reward
    function getReward(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.submissions[self].info.reward;
    }

    /// @dev Returns the list of submissions that have added this Submission as a reference
    function getReferencedIn(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].info.referencedIn;
    }

    /// @dev Returns the number of positive and negative votes for this submission
    function getVotes(address self, address, MatryxPlatform.Data storage data) public view returns (uint256, uint256) {
        return (data.submissions[self].info.positiveVotes, data.submissions[self].info.negativeVotes);
    }

    /// @dev Returns the list of addresses that are permitted to view the files for this submission
    function getViewers(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.submissions[self].allPermittedToView;
    }

    /// @dev Returns the MTX balance of this Submission
    function getBalance(address self, address, MatryxPlatform.Info storage info) public view returns (uint256) {
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
    /// @param sender  msg.sender to this Submission
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

    /// @dev Adds contributors and references on this Submission
    /// @param self          Address of this Submission
    /// @param sender        msg.sender to this Submission
    /// @param info          Info struct on Platform
    /// @param data          Data struct on Platform
    /// @param contribs      Array of contributor addresses
    /// @param dist          Array of contributor distribution values
    /// @param refs          Array of reference addresses
    function addContributorsAndReferences(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address[] contribs, uint256[] dist, address[] refs) public {
        onlyOwner(self, sender, data);
        require(contribs.length == dist.length, "Must include distribution for each contributor");

        LibSubmission.SubmissionDetails storage details = data.submissions[self].details;
        bool flag = false;

        // Add contributors
        for (uint256 i = 0; i < contribs.length; i++) {

            flag = false;
            // Check to avoid duplicates
            for (uint256 j = 0; j < details.contributors.length; j++) {
                if (contribs[i] == details.contributors[j]) {
                    flag = true;
                    break;
                }
            }

            if (!flag) {
                details.contributors.push(contribs[i]);
                details.distribution.push(dist[i]);
                data.users[contribs[i]].contributedTo.push(self);
            }
        }

        // Add references
        for (i = 0; i < refs.length; i++) {
            require(data.submissions[refs[i]].info.owner != 0x0, "Reference must be an existing submission");

            flag = false;
            // Check to avoid duplicates
            for (j = 0; j < details.references.length; j++) {
                if (refs[i] == details.references[j]) {
                    flag = true;
                    break;
                }
            }

            if (!flag) {
                details.references.push(refs[i]);
                data.submissions[refs[i]].info.referencedIn.push(self);
            }
        }
    }

    /// @dev Removes contributors and references on this Submission
    /// @param self          Address of this Submission
    /// @param sender        msg.sender to this Submission
    /// @param info          Info struct on Platform
    /// @param data          Data struct on Platform
    /// @param contribs      Contributor addresses to remove
    /// @param refs          Reference addresses ro remove
    function removeContributorsAndReferences(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address[] contribs, address[] refs) public {
        onlyOwner(self, sender, data);

        address LibUtils = IMatryxSystem(info.system).getContract(info.version, "LibUtils");
        LibSubmission.SubmissionDetails storage details = data.submissions[self].details;

        // Remove contributors and corresponding reward distribution values from submission data
        for (uint256 i = 0; i < contribs.length; i++) {
            for (uint256 j = 0; j < details.contributors.length; j++) {
                if (contribs[i] == details.contributors[j]) {
                    assembly {
                        let offset := 0x100000000000000000000000000000000000000000000000000000000
                        let ptr := mload(0x40)

                        mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                        mstore(add(ptr, 0x04), add(details_slot, 8))                // arg 0 - details.contributors
                        mstore(add(ptr, 0x24), j)                                   // arg 1 - index

                        let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                        if iszero(res) { revert(0, 0) }                             // safety check

                        mstore(add(ptr, 0x04), add(details_slot, 7))                // arg 0 - details.distribution
                        mstore(add(ptr, 0x24), add(j, 1))                           // arg 1 - index

                        res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)         // call LibUtils.removeArrayElement
                        if iszero(res) { revert(0, 0) }                             // safety check
                    }
                    break;
                }
            }

            // Remove submission from user contributedTo data
            address[] storage contributedTo = data.users[contribs[i]].contributedTo;
            for (uint256 k = 0; k < contributedTo.length; k++) {
                if (contributedTo[k] == self) {
                    assembly {
                        let offset := 0x100000000000000000000000000000000000000000000000000000000
                        let ptr := mload(0x40)

                        mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                        mstore(add(ptr, 0x04), contributedTo_slot)                  // arg 0 - users.contributedTo
                        mstore(add(ptr, 0x24), k)                                   // arg 1 - index

                        let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                        if iszero(res) { revert(0, 0) }                             // safety check
                    }
                    break;
                }
            }
        }

        // Remove references from submission data
        for (i = 0; i < refs.length; i++) {
            for (j = 0; j < details.references.length; j++) {
                if (refs[i] == details.references[j]) {
                    assembly {
                        let offset := 0x100000000000000000000000000000000000000000000000000000000
                        let ptr := mload(0x40)

                        mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                        mstore(add(ptr, 0x04), add(details_slot, 9))                // arg 0 - details.references
                        mstore(add(ptr, 0x24), j)                                   // arg 1 - index

                        let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                        if iszero(res) { revert(0, 0) }                             // safety check
                    }
                    break;
                }
            }

            address[] storage referencedIn = data.submissions[refs[i]].info.referencedIn;
            // Remove referencedIn from reference data
            for (k = 0; k < referencedIn.length; k++) {
                if (self == referencedIn[k]) {
                    assembly {
                        let offset := 0x100000000000000000000000000000000000000000000000000000000
                        let ptr := mload(0x40)

                        mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
                        mstore(add(ptr, 0x04), referencedIn_slot)                   // arg 0 - info.referencedIn
                        mstore(add(ptr, 0x24), k)                                   // arg 1 - index

                        let res := delegatecall(gas, LibUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
                        if iszero(res) { revert(0, 0) }                             // safety check
                    }
                    break;
                }
            }
        }
    }

    /// @dev Flags this Submission as missing a reference
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    /// @param ref     Address of the missing reference
    function flagMissingReference(address self, address sender, MatryxPlatform.Data storage data, address ref) public {
        address owner = data.submissions[self].info.owner;
        require(sender == data.submissions[ref].info.owner, "Caller must own the reference");
        require(data.submissions[ref].permittedToView[owner], "Submission owner must have seen the reference's files");

        bool flag = false;
        // Check all missing references
        for (uint256 i = 0; i < data.submissions[self].missingReferences.length; i++) {
            flag = flag || ref == data.submissions[self].missingReferences[i];
            if (flag) break;
        }
        require(!flag, "Cannot flag for the same missing reference twice");

        // Check all submissions already referenced
        for (i = 0; i < data.submissions[self].details.references.length; i++) {
            flag = flag || ref == data.submissions[self].details.references[i];
            if (flag) break;
        }
        require(!flag, "Submission is already a reference");

        // Flag the missing reference
        data.submissions[self].missingReferences.push(ref);

        // Update submission and user votes
        data.submissions[self].info.negativeVotes = data.submissions[self].info.negativeVotes.add(1);
        data.users[owner].negativeVotes = data.users[owner].negativeVotes.add(1);
    }

    /// @dev Get the reward available to the caller on this Submission
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    /// @return        Amount of MTX available to msg.sender
     function getAvailableReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        LibSubmission.SubmissionData storage submission = data.submissions[self];

        uint256 balance = getBalance(self, sender, info);
        uint256 remainingReward = balance.sub(submission.totalAllocated);
        uint256 share = submission.availableReward[sender];

        if (remainingReward > 0) {
            uint256[] storage distribution = submission.details.distribution;
            uint256 distTotal = distribution[0];
            uint256 contributorIndex = 0;

            for (uint256 i = 1; i < distribution.length; i++) {
                distTotal = distTotal.add(distribution[i]);

                if (submission.details.contributors[i - 1] == sender) {
                    contributorIndex = i;
                }
            }

            if (contributorIndex == 0 && sender != submission.info.owner) {
                return share;
            }

            if (submission.details.references.length > 0) {
                uint256 totalRefShare = remainingReward.mul(10**18).div(10**19); // 10% for references
                remainingReward = remainingReward.sub(totalRefShare);    // remaining 90% for owner and contribs
            }

            share = share.add(remainingReward.mul(10**18).mul(distribution[contributorIndex]).div(distTotal).div(10**18));
        }

        return share;
    }

    /// @dev Sets the reward allocation for each contributor and reference to this submission when someone withdraws
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param data    Data struct on Platform
    function calculateRewardAllocation(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) internal {
        LibSubmission.SubmissionData storage submission = data.submissions[self];

        uint256 balance = getBalance(self, sender, info);
        uint256 remainingReward = balance.sub(submission.totalAllocated);

        // if no new reward to allocate, return early
        if (remainingReward == 0) return;
        submission.totalAllocated = submission.totalAllocated.add(remainingReward);

        uint256[] storage distribution = submission.details.distribution;
        uint256 distTotal = 0;

        for (uint256 i = 0; i < distribution.length; i++) {
            distTotal = distTotal.add(distribution[i]);
        }

        if (submission.details.references.length > 0) {
            uint256 totalRefShare = remainingReward.mul(10**18).div(10**19); // 10% for references
            remainingReward = remainingReward.sub(totalRefShare);    // remaining 90% for owner and contribs

            for (i = 0; i < submission.details.references.length; i++) {
                address ref = submission.details.references[i];

                uint256 share = totalRefShare.mul(10**18).div(submission.details.references.length).div(10**18);
                submission.availableReward[ref] = submission.availableReward[ref].add(share);
            }
        }

        for (i = 0; i < distribution.length; i++) {
            share = remainingReward.mul(10**18).mul(distribution[i]).div(distTotal).div(10**18);

            address contrib = submission.info.owner;
            if (i != 0) contrib = submission.details.contributors[i - 1];

            submission.availableReward[contrib] = submission.availableReward[contrib].add(share);
        }
    }

    /// @dev Allows the owner and contributors to this Submission to withdraw from this Submission
    /// @param self    Address of this Submission
    /// @param sender  msg.sender to this Submission
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function withdrawReward(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibSubmission.SubmissionData storage submission = data.submissions[self];
        calculateRewardAllocation(self, sender, info, data);

        uint256 share = submission.availableReward[sender];
        require(share > 0, "Already withdrawn full amount");

        submission.availableReward[sender] = 0;
        data.users[sender].totalWinnings = data.users[sender].totalWinnings.add(share);
        submission.totalAllocated = submission.totalAllocated.sub(share);
        IMatryxSubmission(self).transferTo(info.token, sender, share);

        // if owner, transfer references their shares
        if (sender == submission.info.owner) {
            for (uint256 i = 0; i < submission.details.references.length; i++) {
                address ref = submission.details.references[i];
                share = submission.availableReward[ref];
                if (share == uint256(0)) continue;

                submission.availableReward[ref] = 0;
                data.submissions[ref].info.reward = data.submissions[ref].info.reward.add(share);
                submission.totalAllocated = submission.totalAllocated.sub(share);
                IMatryxSubmission(self).transferTo(info.token, ref, share);
            }
        }
    }
}
