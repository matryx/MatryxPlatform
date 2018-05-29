pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/math/SafeMath.sol';
import '../libraries/strings/strings.sol';
import '../libraries/LibConstruction.sol';
import './reputation/SubmissionTrust.sol';
import '../interfaces/IMatryxToken.sol';
import '../interfaces/IMatryxPeer.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

contract MatryxSubmission is Ownable, IMatryxSubmission {
	using SafeMath for uint256;
	using SafeMath for uint128;
	using SafeMath for uint32;
	using strings for *;


	/************** TODO ******************/
	/* COPY ALL FIELDS TO SUBMISSIONTRUST */           // <------------------ DON'T FORGET.
	/************** TODO ******************/


	// Parent identification
	address private platformAddress;
	address private tournamentAddress;
	address private roundAddress;
	
	// Submission
	string title;
	address author;
	bytes externalAddress;
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
	mapping(address=>uint128) public contributorToBountyDividend;
	uint128 public contributorBountyDivisor;
	uint256 timeSubmitted;
	uint256 timeUpdated;
	bool public publicallyAccessibleDuringTournament;

	address public trustDelegate;
	bytes4 fnSelector_addReference = bytes4(keccak256("addReference(address)"));
	bytes4 fnSelector_removeReference = bytes4(keccak256("removeReference(address)"));
	bytes4 fnSelector_approveReference = bytes4(keccak256("approveReference(address)"));
	bytes4 fnSelector_removeReferenceApproval = bytes4(keccak256("removeReferenceApproval(address)"));
	bytes4 fnSelector_flagMissingReference = bytes4(keccak256("flagMissingReference(address)"));
	bytes4 fnSelector_removeMissingReferenceFlag = bytes4(keccak256("removeMissingReferenceFlag(address)"));

	bytes4 fnSelector_revertIfReferenceFlagged = bytes4(keccak256("revertIfReferenceFlagged(address)"));

	function MatryxSubmission(LibConstruction.RequiredSubmissionAddresses requiredAddresses, LibConstruction.SubmissionData submissionData) public
	{
		author = IMatryxPlatform(platformAddress).peerAddress(submissionData.owner);
		require(author != 0x0);
		
		platformAddress = requiredAddresses.platformAddress;
		tournamentAddress = requiredAddresses.tournamentAddress;
		roundAddress = requiredAddresses.roundAddress;

		title = submissionData.title;
		owner = submissionData.owner;
		externalAddress = submissionData.contentHash;
		references = submissionData.references;
		trustDelegate = IMatryxPlatform(requiredAddresses.platformAddress).getSubmissionTrustLibrary();

		for(uint32 i = 0; i < references.length;i++)
		{
			addressToReferenceInfo[submissionData.references[i]].exists = true;
			addressToReferenceInfo[submissionData.references[i]].index = i;
		}

		addContributors(submissionData.contributors, submissionData.contributorRewardDistribution);
		
		contributors = submissionData.contributors;
		timeSubmitted = now;
	}

	/*
	 * Structs
	 */

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

	/*
	 * Modifiers 
	 */

	modifier onlyAuthor() {
    	require(msg.sender == author);
    	_;
  	}

  	modifier onlyPlatform() {
  		require(msg.sender == platformAddress);
  		_;
  	}

  	// modifier onlyRound()
  	// {
  	// 	require(msg.sender == roundAddress);
  	// 	_;
  	// }

  	modifier ownerOrRound()
  	{
  		require(msg.sender == owner || msg.sender == roundAddress);
  		_;
  	}

  	modifier onlyPeer()
	{
		IMatryxPlatform platform = IMatryxPlatform(platformAddress);
		require(platform.isPeer(msg.sender));
		_;
	}

	// A modifier to ensure that information can only obtained
	// about this submission when it should be.
	modifier whenAccessible(address _requester)
	{
		require(isAccessible(_requester));
		_;
	}

	modifier duringOpenSubmission()
	{
		IMatryxRound round = IMatryxRound(roundAddress);
		require(round.getState() == 1);
		_;
	}

	/*
	 * Getter Methods
	 */

	function getTournament() public constant returns (address) {
		return tournamentAddress;
	}

	function getRound() public constant returns (address) {
		return roundAddress;
	}

	function isAccessible(address _requester) public constant returns (bool)
	{
		IMatryxRound round = IMatryxRound(roundAddress);
		Ownable ownableTournament = Ownable(tournamentAddress);

		bool isPlatform = _requester == IMatryxTournament(tournamentAddress).getPlatform();
		bool isRound = _requester == roundAddress;
		bool ownsThisSubmission = _requester == owner;
		bool submissionExternallyAccessible = publicallyAccessibleDuringTournament;
		bool roundAtLeastInReview = IMatryxRound(roundAddress).getState() >= 2;
		bool requesterIsEntrant = IMatryxTournament(tournamentAddress).isEntrant(_requester);
		bool requesterOwnsTournament = ownableTournament.isOwner(_requester);
		bool duringReviewAndRequesterInTournament = roundAtLeastInReview && (requesterOwnsTournament || requesterIsEntrant);

		return isPlatform || isRound || ownsThisSubmission || submissionExternallyAccessible || duringReviewAndRequesterInTournament || IMatryxPlatform(platformAddress).isPeer(_requester) || IMatryxPlatform(platformAddress).isSubmission(_requester);
	}

	function getTitle() public constant whenAccessible(msg.sender) returns(string) {
		return title;
	}

	function getAuthor() public constant whenAccessible(msg.sender) returns(address) {
		return author;
	}

	function getExternalAddress() public constant whenAccessible(msg.sender) returns (bytes)
	{
		return externalAddress;
	}

	function getReferences() public constant whenAccessible(msg.sender) returns(address[]) {
		return references;
	}

	function getContributors() public constant whenAccessible(msg.sender) returns(address[]) {
		return contributors;
	}

	function getTimeSubmitted() public constant returns(uint256) {
		return timeSubmitted;
	}

	function getTimeUpdated() public constant returns(uint256) {
		return timeUpdated;
	}

	/*
	 * Setter Methods
	 */

	function updateAll(LibConstruction.SubmissionModificationData _data)
	{
		if(!_data.title.toSlice().empty())
		{
			title = _data.title;
		}
		if(_data.owner != 0x0)
		{
			owner = _data.owner;
		}
		if(_data.contentHash.length != 0)
		{
			externalAddress = _data.contentHash;
		}
		if(_data.contributorsToAdd.length != 0)
		{
			require(_data.contributorsToAdd.length == _data.contributorRewardDistribution.length);
			addContributors(_data.contributorsToAdd, _data.contributorRewardDistribution);
		}
		if(_data.contributorsToRemove.length != 0)
		{
			removeContributors(_data.contributorsToRemove);
		}
	}

	function setExternalAccessibility(bool _accessibility) public onlyOwner 
	{
		publicallyAccessibleDuringTournament = _accessibility;
	}

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _title New title for the submission.
	function updateTitle(string _title) public onlyOwner duringOpenSubmission 
	{
		title = _title;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(bytes _externalAddress) public onlyOwner duringOpenSubmission 
	{
		externalAddress = _externalAddress;
		timeUpdated = now;
	}

	function setTrustDelegate(address _newTrustDelegate) public onlyPlatform
	{
		trustDelegate = _newTrustDelegate;
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) /*onlyOwner*/ public onlyOwner
	{
		require(trustDelegate.delegatecall(fnSelector_addReference, _reference));
	}

	// // Debug function. ?MAYBEDO:Delete
	// function addressIsFlagged(address _reference) public constant returns (bool, bool)
	// {
	// 	return (addressToReferenceInfo[_reference].flagged, missingReferenceToIndex[_reference].exists);
	// }

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _reference Address of reference to remove.
	function removeReference(address _reference) /*onlyOwner*/ public onlyOwner
	{
		require(trustDelegate.delegatecall(fnSelector_removeReference, _reference));
	}

	function receiveReferenceRequest() public onlyPlatform
	{
		totalReferenceCount = totalReferenceCount.add(1);
	}

	function cancelReferenceRequest() public onlyPlatform
	{
		totalReferenceCount = totalReferenceCount.sub(1);
	}

	/// @dev Called by the owner of _reference when this submission is approved to list _reference
	/// as a reference.
	/// _reference Reference being approved by msg.sender.
	function approveReference(address _reference) public onlyPeer
	{
		//require(trustDelegate.delegatecall(fnSelector_approveReference, _reference));
	}

	/// @dev 			  Called by the owner of the _reference to remove their approval of a reference
	///		 			  within this submission.
	/// @param _reference Reference that peer is revoking the approval of to be included
	///					  in this submission.
	function removeReferenceApproval(address _reference) public onlyPeer
	{
		//require(trustDelegate.delegatecall(fnSelector_removeReferenceApproval, _reference));
	}

	/// @dev 	Called by the owner of _reference when this submission does not list _reference
	/// 		as a reference.
	/// @param  _reference Missing reference in this submission.
	function flagMissingReference(address _reference) public onlyPeer
	{
		//require(trustDelegate.delegatecall(fnSelector_flagMissingReference, _reference));
	}

	/// @dev 			  Called by the owner of _reference to remove a missing reference flag placed on a reference
	///		 			  as missing.
	/// @param _reference Reference previously marked by peer as missing.
	function removeMissingReferenceFlag(address _reference) public onlyPeer
	{
		//require(trustDelegate.delegatecall(fnSelector_removeMissingReferenceFlag, _reference));
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(address _contributor, uint128 _bountyAllocation) public onlyOwner
	{
		contributors.push(_contributor);

		contributorToBountyDividend[_contributor] = _bountyAllocation;
		contributorBountyDivisor = contributorBountyDivisor + _bountyAllocation;

		IMatryxRound round = IMatryxRound(roundAddress);
		round.setParticipantType(_contributor, 2);
	}

	function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public onlyOwner
	{
		require(_contributorsToAdd.length == _distribution.length);
		for(uint32 j = 0; j < _contributorsToAdd.length; j++)
		{
			contributorBountyDivisor = contributorBountyDivisor + _distribution[j];
			contributorToBountyDividend[_contributorsToAdd[j]] = _distribution[j];
		}
	}	

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _contributorIndex) onlyOwner public onlyOwner
	{
		contributorBountyDivisor = contributorBountyDivisor - contributorToBountyDividend[contributors[_contributorIndex]];
		contributorToBountyDividend[contributors[_contributorIndex]] = 0;

		delete contributors[_contributorIndex];
	}

	function removeContributors(address[] _contributorsToRemove) public onlyOwner
	{
		for(uint32 j = 0; j < _contributorsToRemove.length; j++)
		{
			contributorBountyDivisor = contributorBountyDivisor - contributorToBountyDividend[_contributorsToRemove[j]];
			contributorToBountyDividend[_contributorsToRemove[j]] = 0;
		}
	}

	function getBalance() public returns (uint256)
	{
		IMatryxRound round = IMatryxRound(roundAddress);
		uint256 _balance = round.getBalance(this);
		return _balance;
	}
	
	function withdrawReward(address _recipient) public ownerOrRound
	{
		uint submissionReward = getBalance();
		IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());

		// Transfer reward to submission author and contributors
		uint256 transferAmount = getTransferAmount();
		uint256 authorAmount = transferAmount.div(2);
		token.transfer(_recipient, authorAmount);
		// Distribute transfer amounts to contributors
		uint256 contributorsAmount = transferAmount.sub(authorAmount);
		for(uint i = 0; i < contributors.length; i++)
		{
			if(contributors[i] != 0x0)
			{
				uint256 contributionWeight = (contributorToBountyDividend[contributors[i]]).mul(1*10**18).div(contributorBountyDivisor);
				uint256 contributorReward = contributorsAmount.mul(contributionWeight).div(1*10**18);
				token.transfer(contributors[i], contributorReward);
			}
		}

		// Distribute remaining reward to references
		uint256 remainingReward = submissionReward.sub(transferAmount);
		for(uint j = 0; j < references.length; j++)
		{
			if(addressToReferenceInfo[references[j]].approved)
			{
				uint256 weight = (addressToReferenceInfo[references[j]].authorReputation).mul(1*10**18).div(totalPossibleTrust);
				uint256 weightedReward = remainingReward.mul(weight).div(1*10**18);
				token.transfer(references[j], weightedReward);
			}
		}
	}

	function getTransferAmount() public constant returns (uint256)
	{
		uint submissionReward = getBalance();
		if(totalPossibleTrust == 0)
		{
			if(missingReferences.length > 0)
			{
				return 0;
			}

			return submissionReward;
		}

		// transfer amount calculated as:
		// normalizedAndReferenceCountWeightedTrustInSubmission * 
		// (1 - submissionGratitude) * 
		// submissionReward
		uint256 transferAmount = approvalTrust.mul(1*10**18 - IMatryxPlatform(platformAddress).getSubmissionGratitude());
		transferAmount = transferAmount.div(totalPossibleTrust);
		transferAmount = transferAmount.mul(submissionReward);
		transferAmount = transferAmount.div(1*10**18);

		return transferAmount;
	}

	// function prepareToDelete() internal
	// {
	// 	withdrawReward(owner);
	// 	// TODO: Remove references on other submissions so that MTX is not burned!
	// }

	// // @dev Removes a submission permanently.
 // 	// @param _recipient Address to send the refunded ether to.
	// function deleteSubmission() onlyRound public
	// {
	// 	prepareToDelete();
	// 	selfdestruct(author);
	// }
}