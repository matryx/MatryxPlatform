pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

/// @title MatryxPeer - A peer within the MatryxPlatform.
/// @author Max Howard - <max@nanome.ai>
contract MatryxPeer is Ownable {
	using SafeMath for uint256;

	address platformAddress;

	uint256 globalTrust;
	mapping(address=>uint256) judgedPeerToUnnormalizedTrust;
	address[] judgedPeers;
	uint256 totalTrustGiven;
	mapping(address=>uint256) judgingPeerToUnnormalizedTrust;
	mapping(address=>uint256) judgingPeerToTotalTrustGiven;
	mapping(address=>uint256) judgingPeerToGlobalReputation;

	mapping(address=>uint256) judgingPeerToInfluenceOnMyReputation;
	mapping(address=>bool) peerHasJudgedMe;
	address[] judgingPeers;

	// Tracks the proportion of references this peer has approved on a given submission
	mapping(address=>uint256) submissionToApprovedReferences;
	mapping(address=>uint256) submissionToReferenceCount;

	event ReceivedReferenceRequest(address _submissionAddress, address reference);

	modifier onlyPlatform()
	{
		require(msg.sender == platformAddress);
		_;
	}

	function MatryxPeer(address _owner, uint256 _initialTrust) public
	{
		owner = _owner;
		globalTrust = _initialTrust;
	}

	function getReputation() public constant returns (uint256)
	{
		return globalTrust;
	}

	function invokeReferenceRequestEvent(address _submissionAddress, address _reference) public onlyPlatform
	{
		ReceivedReferenceRequest(_submissionAddress, _reference);
	}

	function trustMe(uint256 _newTotalTrust, uint256 _senderReputation) public
	{
		IMatryxPlatform platform = IMatryxPlatform(platformAddress);
		require(platform.isPeer(msg.sender));
		require(msg.sender != address(this));

		// remove peer's influence on my reputation before adding their new influence
		if(peerHasJudgedMe[msg.sender])
		{
			globalTrust = globalTrust.sub(judgingPeerToInfluenceOnMyReputation[msg.sender]);
		}
		// if we've never been judged by this peer before,
		// update state to reflect that we have now.
		else 
		{
			peerHasJudgedMe[msg.sender] = true;
			judgingPeers.push(msg.sender);
		}

		// update state variables so we can look at them later
		judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].add(1 ether);
		judgingPeerToTotalTrustGiven[msg.sender] = _newTotalTrust;
		// calculate peer's new influence on my reputation
		uint256 peersNewOpinionOfMe = judgingPeerToUnnormalizedTrust[msg.sender].div(_newTotalTrust);
		uint256 peersNewInfluenceOnMyReputation = peersNewOpinionOfMe.mul(_senderReputation);
		judgingPeerToInfluenceOnMyReputation[msg.sender] = peersNewInfluenceOnMyReputation;
		// add this influence to my reputation
		globalTrust = globalTrust.add(peersNewInfluenceOnMyReputation);
	}

	function distrustMe(uint256 _newTotalTrust, uint256 _senderReputation) public returns (bool)
	{
		IMatryxPlatform platform = IMatryxPlatform(platformAddress);
		require(platform.isPeer(msg.sender));
		require(msg.sender != address(this));

		if(judgingPeerToUnnormalizedTrust[msg.sender] < 1)
		{
			return false;
		}

		// remove peer's influence on my reputation before adding their new influence
		if(peerHasJudgedMe[msg.sender])
		{
			globalTrust = globalTrust.sub(judgingPeerToInfluenceOnMyReputation[msg.sender]);
		}
		// if we've never been judged by this peer before,
		// update state to reflect that we have now.
		else
		{
			peerHasJudgedMe[msg.sender] = true;
			judgingPeers.push(msg.sender);
		}

		// update peers unnormalized trust in me
		judgingPeerToUnnormalizedTrust[msg.sender] = judgingPeerToUnnormalizedTrust[msg.sender].sub(1 ether);
		judgingPeerToTotalTrustGiven[msg.sender] = _newTotalTrust;
		// calculate peer's new influence on my reputation
		uint256 peersNewOpinionOfMe = judgingPeerToUnnormalizedTrust[msg.sender].div(_newTotalTrust);
		uint256 peersNewInfluenceOnMyReputation = peersNewOpinionOfMe.mul(_senderReputation);
		judgingPeerToInfluenceOnMyReputation[msg.sender] = peersNewInfluenceOnMyReputation;
		// add this influence to my reputation
		globalTrust = globalTrust.add(peersNewInfluenceOnMyReputation);

		return true;
	}

	/// @dev Flags a missing reference on a submission.
	/// @param _submission Address of the submission to flag.
	/// @param _missingReference Reference that is missing.
	function flagMissingReference(address _submission, address _missingReference) public onlyOwner returns (bool)
	{
		// TODO: Add a way of undoing this missing reference flag.
		// Maybe like removeMissingReferenceFlag

		// Safety checks (we check for peer ownership over _missingReference in MatryxSubmission.approveReference)
		IMatryxPlatform platform = IMatryxPlatform(platformAddress);
		require(platform.isSubmission(_submission));
		IMatryxSubmission submission = IMatryxSubmission(_submission);
		address author = submission.getAuthor();
		require(author == msg.sender);

		submission.flagMissingReference(_missingReference);

		if(judgedPeerToUnnormalizedTrust[author] >= 1)
		{
			judgedPeerToUnnormalizedTrust[author] = judgedPeerToUnnormalizedTrust[author].sub(1 ether);
			totalTrustGiven = totalTrustGiven.sub(1);
		}

		return MatryxPeer(author).distrustMe(totalTrustGiven, globalTrust);
	}

	// @dev Approve of a reference to a submission written by this peer.
	/// @param _submission Address of the submission on which to approve a reference.
	/// @param _reference Reference to approve.
	function approveReference(address _submission, address _reference) public onlyOwner
	{
		// TODO: Add a way of undoing this reference approval.
		// Maybe like removeReferenceApproval

		// Safety checks (we check for peer ownership over _reference in MatryxSubmission.approveReference)
		IMatryxPlatform platform = IMatryxPlatform(platformAddress);
		require(platform.isSubmission(_submission));
		IMatryxSubmission submission = IMatryxSubmission(_submission);
		address author = submission.getAuthor();
		require(author == msg.sender);

		submission.approveReference(_reference);
		
		judgedPeerToUnnormalizedTrust[author] = judgedPeerToUnnormalizedTrust[author].add(1 *10**18);
		totalTrustGiven = totalTrustGiven.add(1);
		submissionToApprovedReferences[_submission] = submissionToApprovedReferences[_submission].add(1);

		MatryxPeer(author).trustMe(totalTrustGiven, globalTrust);
	}

	function getTotalReferenceCount(address _submissionAddress) public constant returns (uint256)
	{
		return submissionToReferenceCount[_submissionAddress];
	}

	function peersJudged() public constant returns (uint256)
	{
		return judgedPeers.length;
	}

	function normalizedTrustInPeer(address _peer) public constant returns (uint256)
	{
		uint256 normalizedTrust = judgedPeerToUnnormalizedTrust[_peer].div(totalTrustGiven);
		if(normalizedTrust > 0)
		{
			return uint256(normalizedTrust);
		}

		return 0;
	}
}