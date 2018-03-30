pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
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

	function MatryxSubmission(address _platformAddress, address _tournamentAddress, address _roundAddress, string _title, address _submissionOwner, address _submissionAuthor, bytes _externalAddress, address[] _references, address[] _contributors, bool _publicallyAccessibleDuringTournament) public
	{
		require(_submissionAuthor != 0x0);
		
		platformAddress = _platformAddress;
		tournamentAddress = _tournamentAddress;
		roundAddress = _roundAddress;

		title = _title;
		owner = _submissionOwner;
		author = _submissionAuthor;
		externalAddress = _externalAddress;
		references = _references;
		trustDelegate = IMatryxPlatform(_platformAddress).getSubmissionTrustLibrary();

		for(uint32 i = 0; i < references.length;i++)
		{
			addressToReferenceInfo[references[i]].exists = true;
			addressToReferenceInfo[references[i]].index = i;
		}
		
		contributors = _contributors;
		timeSubmitted = now;
		publicallyAccessibleDuringTournament = _publicallyAccessibleDuringTournament;
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

  	modifier onlyRound()
  	{
  		require(msg.sender == roundAddress);
  		_;
  	}

  	modifier ownerOrRound()
  	{
  		bool isOwner = msg.sender == owner;
  		bool isRound = msg.sender == roundAddress;
  		require(isOwner || isRound);
  		_;
  	}

  	modifier onlyOwningPeer(address _reference)
  	{
  		require(IMatryxPlatform(platformAddress).peerExistsAndOwnsSubmission(msg.sender, _reference));
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
		require(round.isOpen());
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
		bool ownsThisSubmission = _requester == author;
		bool submissionExternallyAccessible = publicallyAccessibleDuringTournament;
		bool duringReviewPeriod = IMatryxRound(roundAddress).isInReview() || IMatryxTournament(tournamentAddress).isInReview();
		bool requesterIsEntrant = IMatryxTournament(tournamentAddress).isEntrant(_requester);
		bool requesterOwnsTournament = ownableTournament.isOwner(_requester);
		bool duringReviewAndRequesterInTournament = duringReviewPeriod && (requesterOwnsTournament || requesterIsEntrant);
		bool roundClosed = !round.isOpen();

		return isPlatform || isRound || ownsThisSubmission || submissionExternallyAccessible || duringReviewAndRequesterInTournament || roundClosed;
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

	function makeExternallyAccessibleDuringTournament() onlyOwner public
	{
		publicallyAccessibleDuringTournament = true;
	}

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _title New title for the submission.
	function updateTitle(string _title) onlyOwner duringOpenSubmission public 
	{
		title = _title;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(bytes _externalAddress) onlyOwner duringOpenSubmission public
	{
		externalAddress = _externalAddress;
		timeUpdated = now;
	}

	function setTrustDelegate(address _newTrustDelegate) onlyOwner public
	{
		trustDelegate = _newTrustDelegate;
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) onlyOwner public 
	{
		require(trustDelegate.delegatecall(fnSelector_addReference, _reference));
	}

	function addressIsFlagged(address _reference) public constant returns (bool, bool)
	{
		return (addressToReferenceInfo[_reference].flagged, missingReferenceToIndex[_reference].exists);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _reference Address of reference to remove.
	function removeReference(address _reference) onlyOwner public
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
	function approveReference(address _reference) public
	{
		require(trustDelegate.delegatecall(fnSelector_approveReference, _reference));
	}

	/// @dev 			  Called by the owner of the _reference to remove their approval of a reference
	///		 			  within this submission.
	/// @param _reference Reference that peer is revoking the approval of to be included
	///					  in this submission.
	function removeReferenceApproval(address _reference) public
	{
		require(trustDelegate.delegatecall(fnSelector_removeReferenceApproval, _reference));
	}

	/// @dev 	Called by the owner of _reference when this submission does not list _reference
	/// 		as a reference.
	/// @param  _reference Missing reference in this submission.
	function flagMissingReference(address _reference) public
	{
		require(trustDelegate.delegatecall(fnSelector_flagMissingReference, _reference));
	}

	/// @dev 			  Called by the owner of _reference to remove a missing reference flag placed on a reference
	///		 			  as missing.
	/// @param _reference Reference previously marked by peer as missing.
	function removeMissingReferenceFlag(address _reference) public
	{
		require(trustDelegate.delegatecall(fnSelector_removeMissingReferenceFlag, _reference));
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(address _contributor) onlyOwner public
	{
		contributors.push(_contributor);

		IMatryxRound round = IMatryxRound(roundAddress);
		round.setParticipantType(_contributor, 2);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _contributorIndex) onlyOwner public 
	{
		delete contributors[_contributorIndex];
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

		// Transfer reward to submission author
		uint256 transferAmount = getTransferAmount();
		token.transfer(_recipient, transferAmount);

		// Distribute reward to references
		uint256 remainingReward = submissionReward.sub(transferAmount);
		for(uint i = 0; i < references.length; i++)
		{
			if(addressToReferenceInfo[references[i]].approved)
			{
				uint256 weight = (addressToReferenceInfo[references[i]].authorReputation).mul(1*10**18).div(totalPossibleTrust);
				uint256 weightedReward = remainingReward.mul(weight).div(1*10**18);
				token.transfer(references[i], weightedReward);
			}
		}
	}

	function withdrawReward() public ownerOrRound
	{
		// withdrawReward(msg.sender);
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

	function prepareToDelete() internal
	{
		withdrawReward();
		// TODO: Remove references on other submissions so that MTX is not burned!
	}

	// @dev Removes a submission permanently.
 	// @param _recipient Address to send the refunded ether to.
	function deleteSubmission() onlyRound public
	{
		prepareToDelete();
		selfdestruct(author);
	}
}