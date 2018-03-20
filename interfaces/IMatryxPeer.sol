pragma solidity ^0.4.18;

interface IMatryxPeer
{
	function getReputation() public constant returns (uint128);
	function receiveReferenceRequest(address _submissionAddress, address _reference) public;
	function receiveCancelledReferenceRequest(address _submissionAddress, address _reference) public;
	function receiveTrust(uint128 _newTotalTrust, uint128 _senderReputation) public;
	function receiveDistrust(uint128 _newTotalTrust, uint128 _senderReputation) public returns (bool);
	function flagMissingReference(address _submissionAddress, address _missingReference) public returns (bool);
	function removeMissingReferenceFlag(address _submissionAddress, address _missingReference) public;
	function approveReference(address _submissionAddress, address _reference) public;
	function removeReferenceApproval(address _submissionAddress, address _reference) public;
	function getApprovedReferenceProportion(address _submissionAddress) public constant returns (uint128);
	function peersJudged() public constant returns (uint256);
	function normalizedTrustInPeer(address _peer) public constant returns (uint128);
}