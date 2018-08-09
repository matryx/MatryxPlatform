pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../math/SafeMath.sol";
import "../math/SafeMath128.sol";
import "../LibConstruction.sol";
import "../submission/LibSubmissionTrust.sol";
import "../strings/strings.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxSubmission.sol";
import "../../interfaces/IOwnable.sol";

library LibSubmission
{
    using SafeMath128 for uint128;
    using SafeMath for uint256;
    using strings for *;

    struct RewardData
    {
        uint256 winnings;
        uint256 amountTransferredToReferences;
        uint256 contributorBountyDivisor;
        mapping(address=>uint256) contributorToBountyDividend;
        mapping(address=>uint256) addressToAmountWithdrawn;
    }

    struct TrustData
    {
        uint128 approvalTrust;
        uint256 totalPossibleTrust;
        uint256 approvedReferenceCount;
        uint256 totalReferenceCount;
        address[] approvingPeers;
        address[] missingReferences;
        mapping(address=>uint128_optional) missingReferenceToIndex;
        mapping(address=>ReferencedSubmissionInfo) addressToReferenceInfo;
        mapping(address=>ReferencedAuthorStats) referenceStatsByAuthor;
        mapping(address=>uint128) authorToApprovalTrustGiven;
    }

    struct ReferencedSubmissionInfo
    {
        uint32 index;
        bool exists;
        bool approved;
        bool flagged;
        uint128 negativeReputationEffect;
        uint128 positiveReputationEffect;
        uint128 authorReputation;
    }

    struct ReferencedAuthorStats
    {
        uint128 numberMissing;
        uint128 numberApproved;
    }

    struct FileDownloadTracking
    {
        mapping(address=>bool) permittedToViewFile;
        address[] allPermittedToViewFile;
    }

    struct uint128_optional
    {
        bool exists;
        uint128 value;
    }

    uint256 constant one = 10**18;

    function updateData(LibConstruction.SubmissionData storage data, LibConstruction.SubmissionModificationData _modificationData) public
    {
        if(!(_modificationData.title[0] == 0x0))
        {
            data.title = _modificationData.title;
        }
        if(_modificationData.descriptionHash.length != 0)
        {
            data.descriptionHash = _modificationData.descriptionHash;
        }
        if(_modificationData.fileHash.length != 0)
        {
            data.fileHash = _modificationData.fileHash;
        }
        data.timeUpdated = now;
    }

    function updateContributors(LibConstruction.SubmissionData storage data, LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, LibConstruction.ContributorsModificationData _contributorsModificationData) public
    {
        if(_contributorsModificationData.contributorsToAdd.length != 0)
        {
            require(_contributorsModificationData.contributorsToAdd.length == _contributorsModificationData.contributorRewardDistribution.length);
            addContributors(contributorsAndReferences, rewardData, _contributorsModificationData.contributorsToAdd, _contributorsModificationData.contributorRewardDistribution);
        }

        if(_contributorsModificationData.contributorsToRemove.length != 0)
        {
            removeContributors(contributorsAndReferences, rewardData, _contributorsModificationData.contributorsToRemove);
        }

        data.timeUpdated = now;
    }

    function updateReferences(address platformAddress, LibConstruction.SubmissionData storage data, LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.TrustData storage trustData, LibConstruction.ReferencesModificationData _referencesModificationData) public
    {
        if(_referencesModificationData.referencesToAdd.length != 0)
        {
            LibSubmissionTrust.addReferences(platformAddress, contributorsAndReferences, trustData, _referencesModificationData.referencesToAdd);
        }

        if(_referencesModificationData.referencesToRemove.length != 0)
        {
            removeReferences(contributorsAndReferences, trustData, _referencesModificationData.referencesToRemove);
        }

        data.timeUpdated = now;
    }

    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, LibSubmission.TrustData storage trustData, LibSubmission.FileDownloadTracking storage downloadData, LibConstruction.ContributorsAndReferences _contribsAndRefs) public
    {
        require(_contribsAndRefs.contributors.length == _contribsAndRefs.contributorRewardDistribution.length);

        rewardData.contributorBountyDivisor = 0;

        for(uint32 i = 0; i < _contribsAndRefs.contributors.length; i++)
        {
            // if one of the contributors is already there, revert
            // otherwise, add it to the list
            address contributor = _contribsAndRefs.contributors[i];
            uint256 dist = _contribsAndRefs.contributorRewardDistribution[i];
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(dist);
            rewardData.contributorToBountyDividend[contributor] = dist;

            if(downloadData.permittedToViewFile[contributor] == false)
            {
                downloadData.permittedToViewFile[contributor] = true;
                downloadData.allPermittedToViewFile.push(contributor);
            }
        }

        for(i = 0; i < _contribsAndRefs.references.length; i++)
        {
            address reference = _contribsAndRefs.references[i];
            trustData.addressToReferenceInfo[reference].exists = true;
            trustData.addressToReferenceInfo[reference].index = i;
        }

        contributorsAndReferences.contributors = _contribsAndRefs.contributors;
        contributorsAndReferences.references = _contribsAndRefs.references;
    }

    // function addContributors(LibConstruction.ContributorsModificationData storage _contributorsModificationData) internal
    function addContributors(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, address[] _contributorsToAdd, uint256[] _distribution) public
    {
        require(_contributorsToAdd.length == _distribution.length);
        for(uint32 i = 0; i < _contributorsToAdd.length; i++)
        {
            uint256 dist = _distribution[i];
            // can't have 0 proportion
            require(dist != 0);

            // if one of the contributors is already there, update their distribution
            // otherwise, add it to the list
            address contributor = _contributorsToAdd[i];
            uint256 dividend = rewardData.contributorToBountyDividend[contributor];

            if (dividend != 0) {
                rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(dividend);
            }

            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(dist);
            rewardData.contributorToBountyDividend[contributor] = dist;

            if (dividend == 0) {
                contributorsAndReferences.contributors.push(contributor);
            }
        }
    }

    function removeContributors(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, uint256[] _contributorsToRemove) public
    {
        for(uint32 i = 0; i < _contributorsToRemove.length; i++)
        {
            address contributor = contributorsAndReferences.contributors[_contributorsToRemove[i]];
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(rewardData.contributorToBountyDividend[contributor]);
            rewardData.contributorToBountyDividend[contributor] = 0;
        }

        // TODO: Swap with above and test
        // assembly {
            // let len := arg(1) // array length
            // for { let i := 0 } lt(i, len) { i := add(i, 1) } {
            //     let contrib := calldataload(add(0x04, add(arg(0), mul(0x20, i)))) // arg(0) is offset of _contribs... in bytes
            //     mstore(0x0, contrib)
            //     mstore(0x20, add(rewardData_slot, 3)) // RewardData.contributorToBountyDividend
            //     let s_dividend := keccak256(0x0, 0x40)
            //     let dividend := sload(s_dividend)
            //     sstore(add(rewardData_slot, 2), sub(sload(add(rewardData_slot, 2)), dividend)) // RewardData.contributorToBountyDivisor

            //     sstore(s_dividend, 0)
            // }
        // }

        assembly {
            let ptr := mload(0x40)

            let arrLen := sload(contributorsAndReferences_slot)
            let end := sub(arrLen, 1)

            mstore(0, contributorsAndReferences_slot)
            let s_cons := keccak256(0, 0x20)

            let c_ids := add(_contributorsToRemove, 0x24)
            let idsLen := calldataload(sub(c_ids, 0x20))

            // clear out flag memory
            for { let i := 0 } lt(i, arrLen) { i := add(i, 1) } {
                mstore(add(ptr, mul(i, 0x20)), 0)
            }

            // flag items in memory
            for { let i := 0 } lt(i, idsLen) { i := add(i, 1) } {
                let id := calldataload(add(c_ids, mul(i, 0x20)))
                mstore(add(ptr, mul(id, 0x20)), 1) // flag for replace
            }

            let last := 0
            // loop through and replace flagged
            for { let i := 0 } lt(i, end) { i := add(i, 1) } {
                if eq(mload(add(ptr, mul(i, 0x20))), 1) {
                    let flagged := 1
                    for {} and(eq(flagged, 1), gt(end, 0)) {} {
                        flagged := mload(add(ptr, mul(end, 0x20)))

                        if iszero(flagged) {
                            last := sload(add(s_cons, end))
                        }

                        end := sub(end, 1)
                    }

                    sstore(add(s_cons, i), last) // replace
                }
            }

            // update contributors length
            sstore(contributorsAndReferences_slot, sub(arrLen, idsLen))
        }
    }

    /// @dev Removes references to a submission (callable only by submission's owner).
    /// @param _referencesToRemove Indices of references to remove.
    function removeReferences(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.TrustData storage trustData, uint256[] _referencesToRemove) public
    {
        for (uint256 i = 0; i < _referencesToRemove.length; i++) {
            address reference = contributorsAndReferences.references[_referencesToRemove[i]];
            require(trustData.addressToReferenceInfo[reference].exists);
            delete trustData.addressToReferenceInfo[reference];
        }

        assembly {
            let ptr := mload(0x40)

            // contributorsAndReferences.references
            let arrLen := sload(add(contributorsAndReferences_slot, 2))
            let end := sub(arrLen, 1)

            mstore(0, add(contributorsAndReferences_slot, 2))
            let s_refs := keccak256(0, 0x20)

            let c_ids := add(_referencesToRemove, 0x44)
            let idsLen := calldataload(sub(c_ids, 0x20))

            // clear out flag memory
            for { let i := 0 } lt(i, arrLen) { i := add(i, 1) } {
                mstore(add(ptr, mul(i, 0x20)), 0)
            }

            // flag items in memory
            for { let i := 0 } lt(i, idsLen) { i := add(i, 1) } {
                let id := calldataload(add(c_ids, mul(i, 0x20)))
                mstore(add(ptr, mul(id, 0x20)), 1) // flag for replace
            }

            let last := 0
            // loop through and replace flagged
            for { let i := 0 } lt(i, end) { i := add(i, 1) } {
                if eq(mload(add(ptr, mul(i, 0x20))), 1) {
                    let flagged := 1
                    for {} and(eq(flagged, 1), gt(end, 0)) {} {
                        flagged := mload(add(ptr, mul(end, 0x20)))

                        if iszero(flagged) {
                            last := sload(add(s_refs, end))
                        }

                        end := sub(end, 1)
                    }

                    sstore(add(s_refs, i), last) // replace
                }
            }

            // update references length
            sstore(add(contributorsAndReferences_slot, 2), sub(arrLen, idsLen))
        }
    }

    function withdrawReward(address platformAddress, LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, LibSubmission.TrustData storage trustData) public
    {
        IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());
        uint256 submissionReward = rewardData.winnings;

        // Transfer reward to submission author and contributors
        uint256 transferAmount = getTransferAmount(platformAddress, rewardData, trustData);
        uint256 transferAmountLeft = _myReward(contributorsAndReferences, rewardData, msg.sender, transferAmount);

        token.transfer(msg.sender, transferAmountLeft);
        rewardData.addressToAmountWithdrawn[msg.sender] = rewardData.addressToAmountWithdrawn[msg.sender].add(transferAmountLeft);

        if (IOwnable(this).isOwner(msg.sender))
        {
            // Distribute remaining reward to references
            uint256 remainingReward = submissionReward.sub(transferAmount).sub(rewardData.amountTransferredToReferences);
            if(remainingReward == 0) return;

            uint256 weight = (one).div(trustData.approvedReferenceCount);
            uint256 weightedReward = weight.mul(remainingReward).div(one);
            for(uint j = 0; j < contributorsAndReferences.references.length; j++)
            {
                if(trustData.addressToReferenceInfo[contributorsAndReferences.references[j]].approved)
                {
                    // TODO: Revisit with trust system
                    // uint256 weight = (addressToReferenceInfo[contributorsAndReferences.references[j]].authorReputation).mul(10**18).div(totalPossibleTrust);
                    // uint256 weightedReward = remainingReward.mul(weight).div(10**18);
                    // token.transfer(contributorsAndReferences.references[j], weightedReward);
                    // IMatryxSubmission(contributorsAndReferences.references[j]).addToWinnings(weightedReward);
                    token.transfer(contributorsAndReferences.references[j], weightedReward);
                    IMatryxSubmission(contributorsAndReferences.references[j]).addToWinnings(weightedReward);
                }
            }
            rewardData.amountTransferredToReferences = rewardData.amountTransferredToReferences.add(remainingReward);
        }
    }

    function getTransferAmount(address platformAddress, LibSubmission.RewardData storage rewardData, LibSubmission.TrustData storage trustData) public view returns (uint256)
    {
        uint256 submissionReward = rewardData.winnings;
        if(trustData.totalPossibleTrust == 0)
        {
            if(trustData.missingReferences.length > 0)
            {
                return 0;
            }

            return submissionReward;
        }

        // TODO: Revisit with trust system
        // transfer amount calculated as:
        // normalizedAndReferenceCountWeightedTrustInSubmission *
        // (1 - submissionGratitude) *
        // submissionReward

        // uint256 transferAmount = uint256(approvalTrust).mul(one - IMatryxPlatform(platformAddress).getSubmissionGratitude());
        uint256 transferAmount = one - IMatryxPlatform(platformAddress).getSubmissionGratitude();
        // transferAmount = transferAmount.div(totalPossibleTrust);
        transferAmount = transferAmount.mul(submissionReward);
        transferAmount = transferAmount.div(one);

        return transferAmount;
    }

    function _myReward(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, address _sender, uint256 transferAmount) public view returns(uint256)
    {
        uint256 authorReward = transferAmount;
        if (contributorsAndReferences.contributors.length != 0) {
            authorReward = authorReward.div(2);
        }

        if(IOwnable(this).isOwner(_sender))
        {
            return authorReward.sub(rewardData.addressToAmountWithdrawn[_sender]);
        }

        uint256 contributorRewardWeight = uint256(rewardData.contributorToBountyDividend[_sender]).mul(one).div(uint256(rewardData.contributorBountyDivisor));
        return contributorRewardWeight.mul(authorReward).div(one).sub(rewardData.addressToAmountWithdrawn[_sender]);
    }
}
