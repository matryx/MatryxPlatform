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
        uint128 contributorBountyDivisor;
        mapping(address=>uint128) contributorToBountyDividend;
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
            // TODO: Finish and test
            // removeContributors(contributorsAndReferences, rewardData, _contributorsModificationData.contributorsToRemove);
        }
        data.timeUpdated = now;

    }

    function updateReferences(address platformAddress, LibConstruction.SubmissionData storage data, LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.TrustData storage trustData, LibConstruction.ReferencesModificationData _referencesModificationData) public
    {
        if(_referencesModificationData.referencesToAdd.length != 0)
        {
            LibSubmissionTrust.addReferences(platformAddress, contributorsAndReferences, trustData, _referencesModificationData.referencesToAdd);
        }
        // TODO: Add remove functionality
        data.timeUpdated = now;
    }

    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, LibSubmission.TrustData storage trustData, LibConstruction.ContributorsAndReferences _contribsAndRefs) public
    {
        require(_contribsAndRefs.contributors.length == _contribsAndRefs.contributorRewardDistribution.length);
        for(uint32 i = 0; i < _contribsAndRefs.contributors.length; i++)
        {
            // if one of the contributors is already there, revert
            // otherwise, add it to the list
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(_contribsAndRefs.contributorRewardDistribution[i]);
            rewardData.contributorToBountyDividend[_contribsAndRefs.contributors[i]] = _contribsAndRefs.contributorRewardDistribution[i];
        }

        for(i = 0; i < _contribsAndRefs.references.length; i++)
        {
            trustData.addressToReferenceInfo[_contribsAndRefs.references[i]].exists = true;
            trustData.addressToReferenceInfo[_contribsAndRefs.references[i]].index = i;
        }

        contributorsAndReferences.contributors = _contribsAndRefs.contributors;
        contributorsAndReferences.contributorRewardDistribution = _contribsAndRefs.contributorRewardDistribution;
        contributorsAndReferences.references = _contribsAndRefs.references;
    }

    // function addContributors(LibConstruction.ContributorsModificationData storage _contributorsModificationData) internal
    function addContributors(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, address[] _contributorsToAdd, uint128[] _distribution) internal
    {
        require(_contributorsToAdd.length == _distribution.length);
        for(uint32 i = 0; i < _contributorsToAdd.length; i++)
        {
            // if one of the contributors is already there, revert
            // otherwise, add it to the list
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(_distribution[i]);
            rewardData.contributorToBountyDividend[_contributorsToAdd[i]] = _distribution[i];
            contributorsAndReferences.contributors.push(_contributorsToAdd[i]);
        }
    }

    function removeContributors(LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.RewardData storage rewardData, address[] _contributorsToRemove) public
    {
        for(uint32 i = 0; i < _contributorsToRemove.length; i++)
        {
            rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.sub(rewardData.contributorToBountyDividend[_contributorsToRemove[i]]);
            rewardData.contributorToBountyDividend[_contributorsToRemove[i]] = 0;
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
