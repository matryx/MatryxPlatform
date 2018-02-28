pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxToken.sol';
import '../interfaces/IMatryxPeer.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

contract MatryxSubmission is Ownable, IMatryxSubmission {
	using SafeMath for uint256;

	// Parent identification
	address public platformAddress;
	address public tournamentAddress;
	address public roundAddress;
	
	// Submission
	string title;
	address author;
	bytes32 externalAddress;
	address[] references;

	// Tracks the normalized trust gained through peers approving this submission
	mapping(address=>uint256) authorToApprovalTrustGiven;
	uint256 approvalTrust;
	uint256 totalPossibleTrust;
	address[] approvingPeers;

	// Tracks the proportion of references this submission has approved
	mapping(address=>uint256_optional) missingReferenceToIndex;
	address[] missingReferences;
	mapping(address=>ReferenceInfo) addressToReferenceInfo;
	uint256 approvedReferences;
	uint256 totalReferenceCount;

	address[] contributors;
	uint256 timeSubmitted;
	bool public publicallyAccessibleDuringTournament;

	function MatryxSubmission(address _platformAddress, address _tournamentAddress, address _roundAddress, string _title, address _submissionAuthor, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, bool _publicallyAccessibleDuringTournament) public
	{
		require(_submissionAuthor != 0x0);
		
		platformAddress = _platformAddress;
		tournamentAddress = _tournamentAddress;
		roundAddress = _roundAddress;

		title = _title;
		owner = _submissionAuthor;
		author = _submissionAuthor;
		externalAddress = _externalAddress;
		references = _references;
		contributors = _contributors;
		timeSubmitted = _timeSubmitted;
		publicallyAccessibleDuringTournament = _publicallyAccessibleDuringTournament;

		IMatryxPlatform(platformAddress).handleReferencesForSubmission(references);
	}

	/*
	 * Structs
	 */

	struct ReferenceInfo
	{
		bool flaggedAsMissing;
		bool isIncluded;
	}

	struct uint256_optional
	{
		bool exists;
		uint256 value;
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

  	modifier owningPeer(address _reference)
  	{
  		require(IMatryxPlatform(platformAddress).peerExistsAndOwnsSubmission(msg.sender, _reference));
  		_;
  	}

	// A modifier to ensure that information can be obtained
	// about this submission only when it should be (when the creator decides it can
	// or after the tournament has been closed).
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

	 function getTournament() public returns (address)
	 {
	 	return tournamentAddress;
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

	function getTitle() constant whenAccessible(msg.sender) public returns(string) {
		return title;
	}

	function getAuthor() constant whenAccessible(msg.sender) public returns(address) {
		return author;
	}

	function getExternalAddress() constant whenAccessible(msg.sender) public returns (bytes32)
	{
		return externalAddress;
	}

	function getReferences() constant whenAccessible(msg.sender) public returns(address[]) {
		return references;
	}

	function getContributors() constant whenAccessible(msg.sender) public returns(address[]) {
		return contributors;
	}

	function getTimeSubmitted() constant whenAccessible(msg.sender) public returns(uint256) {
		return timeSubmitted;
	}

	/*
	 * Setter Methods
	 */

	function makeExternallyAccessibleDuringTournament() onlyAuthor public
	{
		publicallyAccessibleDuringTournament = true;
	}

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _title New title for the submission.
	function updateTitle(string _title) onlyAuthor duringOpenSubmission public 
	{
		title = _title;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(bytes32 _externalAddress) onlyAuthor duringOpenSubmission public
	{
		externalAddress = _externalAddress;
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) onlyAuthor public 
	{
		IMatryxPlatform(platformAddress).handleReferenceForSubmission(_reference);
		references.push(_reference);
		addressToReferenceInfo[_reference].isIncluded = true;
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _referenceIndex Index of reference to remove.
	function removeReference(uint256 _referenceIndex) onlyAuthor public
	{
		delete references[_referenceIndex];
		addressToReferenceInfo[references[_referenceIndex]].isIncluded = false;
		// TODO: Handle affect on reference approval trust
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
	function approveReference(address _reference) public owningPeer(_reference)
	{
		// TODO: Add a way of undoing this reference approval.
		// Maybe like removeReferenceApproval

		require(addressToReferenceInfo[_reference].isIncluded == false);

		IMatryxPeer peer = IMatryxPeer(msg.sender);
		uint256 peersReputation = peer.getReputation();
		
		if(authorToApprovalTrustGiven[msg.sender] == 0x0)
		{	
			approvingPeers.push(msg.sender);
			totalPossibleTrust = totalPossibleTrust.add(peer.getReputation());
		}
		else
		{
			approvalTrust = approvalTrust.sub(authorToApprovalTrustGiven[msg.sender]);
		}

		uint256 peersReferencesInThisSubmission = peer.getTotalReferenceCount(this);
		uint256 trustToAdd = peersReputation.div(peersReferencesInThisSubmission);
		approvalTrust = approvalTrust.add(trustToAdd);

		approvedReferences = approvedReferences.add(1);
		if(missingReferenceToIndex[_reference].exists)
		{
			delete missingReferences[missingReferenceToIndex[_reference].value];
		}
	}

	/// @dev Called by the owner of _reference when this submission does not list _reference
	/// as a reference.
	/// @param _reference Missing reference in this submission.
	function flagMissingReference(address _reference) public owningPeer(_reference)
	{
		// TODO: Add a way of undoing this missing reference flag.
		// Maybe like removeMissingReferenceFlag

		require(addressToReferenceInfo[_reference].flaggedAsMissing == false);
		require(addressToReferenceInfo[_reference].isIncluded == false);
		addressToReferenceInfo[_reference].flaggedAsMissing == true;
		
		IMatryxPeer peer = IMatryxPeer(msg.sender);
		uint256 peersReputation = peer.getReputation();

		if(authorToApprovalTrustGiven[msg.sender] == 0x0)
		{
			approvingPeers.push(msg.sender);
			totalPossibleTrust = totalPossibleTrust.add(peer.getReputation());
		}
		else
		{
			approvalTrust = approvalTrust.sub(authorToApprovalTrustGiven[msg.sender]);
		}

		uint256 peersReferencesInThisSubmission = peer.getTotalReferenceCount(this);
		uint256 trustToAdd = peersReputation.div(peersReferencesInThisSubmission);
		approvalTrust = approvalTrust.add(trustToAdd);

		totalReferenceCount = totalReferenceCount.add(1);

		missingReferences.push(_reference);
		missingReferenceToIndex[_reference] = uint256_optional(true, missingReferences.length-1);
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(address _contributor) onlyAuthor public
	{
		contributors.push(_contributor);

		IMatryxRound round = IMatryxRound(roundAddress);
		round.setParticipantType(_contributor, 2);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _contributorIndex) onlyAuthor public 
	{
		delete contributors[_contributorIndex];
	}

	function getBalance() public returns (uint256)
	{
		IMatryxRound round = IMatryxRound(roundAddress);
		uint256 _balance = round.getBalance(this);
		return _balance;
	}

	function withdrawReward() public ownerOrRound
	{
		uint submissionReward = getBalance();
		IMatryxRound round = IMatryxRound(roundAddress);
		IMatryxToken token = IMatryxToken(round.getTokenAddress());

		// transfer amount calculated as:
		// normalizedTrustInSubmission * 
		// proportionReferenceApprovalsGivenForSubmissionsReferencingThisSubmission *
		// 0.5 * 
		// submissionReward
		uint256 transferAmount = approvalTrust.div(totalPossibleTrust);
		transferAmount = transferAmount.mul(approvedReferences);
		transferAmount = transferAmount.div(totalReferenceCount);
		transferAmount = transferAmount.div(2);
		transferAmount = transferAmount.mul(submissionReward);

		// TODO: Add minimum MTX check.
		// If it passes, just give the owner the remaining amount

		token.transfer(msg.sender, transferAmount);

		// TODO: Weight by author's reputation
		uint256 remainingReward = submissionReward.sub(transferAmount);
		uint256 diviedReward = remainingReward.div(references.length);
		for(uint i = 0; i < references.length; i++)
		{
			token.transfer(references[i], diviedReward);
		}
	}
	
	function withdrawReward(address _recipient) public ownerOrRound
	{
		uint submissionReward = getBalance();
		IMatryxRound round = IMatryxRound(roundAddress);
		IMatryxToken token = IMatryxToken(round.getTokenAddress());

		// transfer amount calculated as:
		// normalizedTrustInSubmission * 
		// proportionReferenceApprovalsGivenForSubmissionsReferencingThisSubmission *
		// 0.5 * 
		// submissionReward
		uint256 transferAmount = approvalTrust.div(totalPossibleTrust);
		transferAmount = transferAmount.mul(approvedReferences);
		transferAmount = transferAmount.div(totalReferenceCount);
		transferAmount = transferAmount.div(2);
		transferAmount = transferAmount.mul(submissionReward);

		// TODO: Add minimum MTX check.
		// If it passes, just give the recipient the remaining amount

		token.transfer(_recipient, transferAmount);

		// TODO: Weight by author's reputation
		uint256 remainingReward = submissionReward.sub(transferAmount);
		uint256 diviedReward = remainingReward.div(references.length);
		for(uint i = 0; i < references.length; i++)
		{
			token.transfer(references[i], diviedReward);
		}
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