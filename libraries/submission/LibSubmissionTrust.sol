pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/math/SafeMath128.sol";
import "../../libraries/math/SafeMath.sol";
import "../../libraries/submission/LibSubmission.sol";
import "../../interfaces/IMatryxSubmission.sol";
import "../../interfaces/IMatryxPlatform.sol";

library LibSubmissionTrust
{
    using SafeMath for uint256;
    using SafeMath128 for uint128;

    function cleanAuthorTrust(LibSubmission.TrustData storage trustData, address _referenceAuthor, address _reference) internal
    {
        // If there are no more approved or flagged references by this author,
        // remove their influence over our reputation (subtract their reputation from
        // this submission's total possible trust value)
        uint128 numberApprovedOrMissing = uint128(trustData.referenceStatsByAuthor[_referenceAuthor].numberApproved).add(uint128(trustData.referenceStatsByAuthor[_referenceAuthor].numberMissing));
        if(numberApprovedOrMissing == 0)
        {
            trustData.totalPossibleTrust = trustData.totalPossibleTrust.sub(trustData.addressToReferenceInfo[_reference].authorReputation);
            trustData.addressToReferenceInfo[_reference].authorReputation = 0;
        }
    }

    function addReferences(address platformAddress, LibConstruction.ContributorsAndReferences storage contributorsAndReferences, LibSubmission.TrustData storage trustData, address[] _references) public
    {
        for(uint32 i = 0; i < _references.length; i++)
        {
            require(trustData.addressToReferenceInfo[_references[i]].exists == false);
            contributorsAndReferences.references.push(_references[i]);
            trustData.addressToReferenceInfo[_references[i]].index = uint32(contributorsAndReferences.references.length-1);
            trustData.addressToReferenceInfo[_references[i]].exists = true;

            if(trustData.addressToReferenceInfo[_references[i]].flagged)
            {
                //TODO - Move peer functions into platform, re-write reputation system

                // address referenceOwner = IMatryxSubmission(_references[i]).getOwner();
                // // If this testing session fails, the below line is the culprit.
                // IMatryxPlatform(platformAddress).removeMissingReferenceFlag(this, _references[i]);
                // cleanAuthorTrust(trustData, referenceOwner, _references[i]);
            }
        }
    }

    /// @dev    Called by the owner of _reference when this submission does not list _reference
    ///         as a reference.
    /// @param  _reference Missing reference in this submission.
    function flagMissingReference(LibSubmission.TrustData storage trustData, address _reference) public
    {
        //TODO - Move peer functions into platform, re-write reputation system

        // require(trustData.addressToReferenceInfo[_reference].exists == false);
        // require(trustData.addressToReferenceInfo[_reference].flagged == false);

        // // Update state variables regarding the missing reference
        // trustData.missingReferences.push(_reference);
        // trustData.missingReferenceToIndex[_reference] = LibSubmission.uint128_optional(true, uint128(trustData.missingReferences.length)-1);
        // trustData.addressToReferenceInfo[_reference].flagged = true;

        // // Update submission reputation state variables
        // uint128 reputation = getReputation(msg.sender);
        // uint128 originalTrust = trustData.approvalTrust;

        // if(trustData.referenceStatsByAuthor[msg.sender].numberMissing == 0)
        // {
        //     trustData.approvingPeers.push(msg.sender);
        // }
        // else
        // {
        //     trustData.approvalTrust = trustData.approvalTrust.sub(trustData.authorToApprovalTrustGiven[msg.sender]);
        //     trustData.totalPossibleTrust = trustData.totalPossibleTrust.sub(trustData.addressToReferenceInfo[_reference].authorReputation);
        // }

        // trustData.referenceStatsByAuthor[msg.sender].numberMissing = uint32(uint128(trustData.referenceStatsByAuthor[msg.sender].numberMissing).add(1));

        // uint128 normalizedProportionOfReferenceApprovals = msg.sender.getReferenceProportion(this);
        // uint128 trustToAdd = reputation.mul(normalizedProportionOfReferenceApprovals);
        // trustToAdd = trustToAdd.div(1*10**18);
        // trustData.authorToApprovalTrustGiven[msg.sender] = trustToAdd;
        // trustData.approvalTrust = trustData.approvalTrust.add(trustToAdd);
        // trustData.addressToReferenceInfo[_reference].authorReputation = reputation;
        // trustData.totalPossibleTrust = trustData.totalPossibleTrust.add(reputation);
        // // Store the difference in reputation that flagging this reference caused to this submission.
        // // We may need this value if this flag is ever revoked by the trust-detracting peer.
        // trustData.addressToReferenceInfo[_reference].negativeReputationEffect = originalTrust.sub(trustData.approvalTrust);

        // trustData.totalReferenceCount = trustData.totalReferenceCount.add(1);
    }

    /// @dev    Called by the owner of _reference to remove a missing reference flag placed on a reference
    ///         as missing.
    /// @param _reference Reference previously marked by peer as missing.
    function removeMissingReferenceFlag(LibSubmission.TrustData storage trustData, address _reference) public
    {
        //TODO - Move peer functions into platform, re-write reputation system

        // //Ensure that this reference was previously flagged as missing (MatryxSubmission)
        // require(trustData.addressToReferenceInfo[_reference].flagged == true);

        // trustData.missingReferenceToIndex[_reference].exists = false;
        // trustData.addressToReferenceInfo[_reference].flagged = false;
        // delete trustData.missingReferences[trustData.missingReferenceToIndex[_reference].value];

        // trustData.referenceStatsByAuthor[msg.sender].numberMissing = uint32(uint128(trustData.referenceStatsByAuthor[msg.sender].numberMissing).sub(1));

        // trustData.approvalTrust = trustData.approvalTrust.add(trustData.addressToReferenceInfo[_reference].negativeReputationEffect);
        // trustData.authorToApprovalTrustGiven[msg.sender] = trustData.authorToApprovalTrustGiven[msg.sender].add(trustData.addressToReferenceInfo[_reference].negativeReputationEffect);
    }
}
