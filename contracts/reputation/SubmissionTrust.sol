pragma solidity ^0.4.18;

import '../../libraries/math/SafeMath.sol';
import '../../libraries/math/SafeMath128.sol';
import '../../interfaces/IMatryxToken.sol';
import '../../interfaces/IMatryxPeer.sol';
import '../../interfaces/IMatryxPlatform.sol';
import '../../interfaces/IMatryxTournament.sol';
import '../../interfaces/IMatryxRound.sol';
import '../../interfaces/IMatryxSubmission.sol';
import '../Ownable.sol';

contract SubmissionTrust is Ownable
{
	using SafeMath for uint256;
	using SafeMath128 for uint128;

	// Parent identification
	address private platformAddress;
	address private tournamentAddress;
	address private roundAddress;
	
	// Submission
	string title;
	address author;
	bytes32 externalAddress;
	address[] references;

	// Tracks the normalized trust gained through peers approving this submission
	mapping(address=>uint128) authorToApprovalTrustGiven;
	uint128 public approvalTrust;
	uint256 public totalPossibleTrust;
	address[] public approvingPeers;

	// Tracks the proportion of references this submission has approved
	mapping(address=>uint128_optional) missingReferenceToIndex;
	address[] public missingReferences;
	mapping(address=>ReferenceInfo) addressToReferenceInfo;
	mapping(address=>ReferenceStats) referenceStatsByAuthor;
	uint256 public approvedReferences;
	uint256 public totalReferenceCount;

	address[] contributors;
	uint256 timeSubmitted;
	uint256 timeUpdated;
	bool public publicallyAccessibleDuringTournament;

	struct ReferenceInfo
	{
		uint32 index;
		bool exists;
		bool approved;
		bool flagged;
		uint128 negativeReputationAffect;
		uint128 positiveReputationAffect;
		uint128 authorReputation;
	}

	struct ReferenceStats
	{
		uint32 numberMissing;
		uint32 numberApproved;
	}

	struct uint128_optional
	{
		bool exists;
		uint128 value;
	}

	function cleanAuthorTrust(address _referenceAuthor, address _reference) internal
	{
		// If there are no more approved or flagged references by this author,
		// remove their influence over our reputation (subtract their reputation from
		// this submission's total possible trust value)
		uint128 numberApprovedOrMissing = uint128(referenceStatsByAuthor[_referenceAuthor].numberApproved).add(uint128(referenceStatsByAuthor[_referenceAuthor].numberMissing));
		if(numberApprovedOrMissing == 0)
		{
			totalPossibleTrust = totalPossibleTrust.sub(addressToReferenceInfo[_reference].authorReputation);
			addressToReferenceInfo[_reference].authorReputation = 0;
		}
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) public 
	{
		require(addressToReferenceInfo[_reference].exists == false);
		IMatryxPlatform(platformAddress).handleReferenceRequestForSubmission(_reference);
		references.push(_reference);
		addressToReferenceInfo[_reference].index = uint32(references.length-1);
		addressToReferenceInfo[_reference].exists = true;

		// We know that the parameter is a valid submission
		// as deemed by the platform. Therefore we're able to
		// get it's author without worrying that we don't
		// know what code we're calling.
		if(addressToReferenceInfo[_reference].flagged)
		{
			address referenceAuthor = IMatryxSubmission(_reference).getAuthor();
			IMatryxPeer(referenceAuthor).removeMissingReferenceFlag(this, _reference);
		}

		cleanAuthorTrust(referenceAuthor, _reference);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _reference Address of reference to remove.
	function removeReference(address _reference) public
	{
		require(addressToReferenceInfo[_reference].exists == true);
		IMatryxPlatform(platformAddress).handleCancelledReferenceRequestForSubmission(_reference);
		// We know that the parameter is a valid submission
		// as deemed by the platform. Therefore we're able to
		// call getAuthor without worrying that we don't
		// know what code we're calling.
		address referenceAuthor = IMatryxSubmission(_reference).getAuthor();
		if(addressToReferenceInfo[_reference].approved)
		{
			IMatryxPeer(referenceAuthor).removeReferenceApproval(this, _reference);
		}

		cleanAuthorTrust(referenceAuthor, _reference);

		uint256 referenceIndex = addressToReferenceInfo[_reference].index;
		delete references[referenceIndex];
		delete addressToReferenceInfo[_reference];
	}

	/// @dev Called by the owner of _reference when this submission is approved to list _reference
	/// as a reference.
	/// _reference Reference being approved by msg.sender.
	function approveReference(address _reference) public
	{
		require(addressToReferenceInfo[_reference].exists == true);
  		require(addressToReferenceInfo[_reference].approved == false);

  		// Update state variables regarding the approved reference
  		approvedReferences = approvedReferences.add(1);
		addressToReferenceInfo[_reference].approved = true;
		if(missingReferenceToIndex[_reference].exists)
		{
			delete missingReferences[missingReferenceToIndex[_reference].value];
		}

  		// Update submission reputation variables
		IMatryxPeer peer = IMatryxPeer(msg.sender);
		uint128 peersReputation = peer.getReputation();
		uint128 originalTrust = approvalTrust;
		
		if(referenceStatsByAuthor[msg.sender].numberApproved == 0)
		{	
			approvingPeers.push(msg.sender);
		}
		else
		{
			approvalTrust = approvalTrust.sub(authorToApprovalTrustGiven[msg.sender]);
			totalPossibleTrust = totalPossibleTrust.sub(addressToReferenceInfo[_reference].authorReputation);
		}

		referenceStatsByAuthor[msg.sender].numberApproved = uint32(uint128(referenceStatsByAuthor[msg.sender].numberApproved).add(1));

		uint128 normalizedProportionOfReferenceApprovals = peer.getApprovedReferenceProportion(this);
		uint128 trustToAdd = peersReputation.mul(normalizedProportionOfReferenceApprovals);
		trustToAdd = trustToAdd.div(1*10**18);
		authorToApprovalTrustGiven[msg.sender] = trustToAdd;
		approvalTrust = approvalTrust.add(trustToAdd);
		addressToReferenceInfo[_reference].authorReputation = peersReputation;
		totalPossibleTrust = totalPossibleTrust.add(peersReputation);
		// Store the difference in reputation that approving this reference caused to this submission.
		// We may need this value if this approval is ever revoked by the trust-lending peer.
		addressToReferenceInfo[_reference].positiveReputationAffect = approvalTrust.sub(originalTrust);
	}

	/// @dev 			  Called by the owner of the _reference to remove their approval of a reference
	///		 			  within this submission.
	/// @param _reference Reference that peer is revoking the approval of to be included
	///					  in this submission.
	function removeReferenceApproval(address _reference) public
	{
		require(addressToReferenceInfo[_reference].approved = true);

		approvedReferences = approvedReferences.sub(1);
		addressToReferenceInfo[_reference].approved = false;

		if(addressToReferenceInfo[_reference].flagged)
		{
			// TODO: TEST THIS THOROUGHLY.
			missingReferences[missingReferenceToIndex[_reference].value] = _reference;
		}

		referenceStatsByAuthor[msg.sender].numberApproved = uint32(uint128(referenceStatsByAuthor[msg.sender].numberApproved).sub(1));

		approvalTrust = approvalTrust.sub(addressToReferenceInfo[_reference].positiveReputationAffect);
		authorToApprovalTrustGiven[msg.sender] = authorToApprovalTrustGiven[msg.sender].sub(addressToReferenceInfo[_reference].positiveReputationAffect);
	}

	/// @dev 	Called by the owner of _reference when this submission does not list _reference
	/// 		as a reference.
	/// @param  _reference Missing reference in this submission.
	function flagMissingReference(address _reference) public
	{
		require(addressToReferenceInfo[_reference].exists == false);
  		require(addressToReferenceInfo[_reference].flagged == false);

		// Update state variables regarding the missing reference
		missingReferences.push(_reference);
		missingReferenceToIndex[_reference] = uint128_optional(true, uint128(missingReferences.length)-1);
		addressToReferenceInfo[_reference].flagged = true;
		
		// Update submission reputation state variables
		IMatryxPeer peer = IMatryxPeer(msg.sender);
		uint128 peersReputation = peer.getReputation();
		uint128 originalTrust = approvalTrust;

		if(referenceStatsByAuthor[msg.sender].numberMissing == 0)
		{
			approvingPeers.push(msg.sender);
		}
		else
		{
			approvalTrust = approvalTrust.sub(authorToApprovalTrustGiven[msg.sender]);
			totalPossibleTrust = totalPossibleTrust.sub(addressToReferenceInfo[_reference].authorReputation);
		}

		referenceStatsByAuthor[msg.sender].numberMissing = uint32(uint128(referenceStatsByAuthor[msg.sender].numberMissing).add(1));

		uint128 normalizedProportionOfReferenceApprovals = peer.getApprovedReferenceProportion(this);
		uint128 trustToAdd = peersReputation.mul(normalizedProportionOfReferenceApprovals);
		trustToAdd = trustToAdd.div(1*10**18);
		authorToApprovalTrustGiven[msg.sender] = trustToAdd;
		approvalTrust = approvalTrust.add(trustToAdd);
		addressToReferenceInfo[_reference].authorReputation = peersReputation;
		totalPossibleTrust = totalPossibleTrust.add(peersReputation);
		// Store the difference in reputation that flagging this reference caused to this submission.
		// We may need this value if this flag is ever revoked by the trust-detracting peer.
		addressToReferenceInfo[_reference].negativeReputationAffect = originalTrust.sub(approvalTrust);

		totalReferenceCount = totalReferenceCount.add(1);
	}

	/// @dev 			  Called by the owner of _reference to remove a missing reference flag placed on a reference
	///		 			  as missing.
	/// @param _reference Reference previously marked by peer as missing.
	function removeMissingReferenceFlag(address _reference) public
	{
		// TODO: Ensure that this reference was previously flagged as missing (MatryxSubmission)
		require(addressToReferenceInfo[_reference].flagged == true);

		missingReferenceToIndex[_reference].exists = false;
		addressToReferenceInfo[_reference].flagged = false;
		delete missingReferences[missingReferenceToIndex[_reference].value];

		referenceStatsByAuthor[msg.sender].numberMissing = uint32(uint128(referenceStatsByAuthor[msg.sender].numberMissing).sub(1));
		
		approvalTrust = approvalTrust.add(addressToReferenceInfo[_reference].negativeReputationAffect);
		authorToApprovalTrustGiven[msg.sender] = authorToApprovalTrustGiven[msg.sender].add(addressToReferenceInfo[_reference].negativeReputationAffect);
	}
}