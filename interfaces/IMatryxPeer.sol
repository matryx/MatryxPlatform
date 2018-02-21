pragma solidity ^0.4.18;

interface IMatryxPeer
{
	function getReputation() public constant returns (uint256);
	function invokeReferenceRequestEvent(address _submissionAddress, address _reference) public;
	function trustMe(uint256 _newTotalTrust, uint256 _senderReputation) public;
	function distrustMe(uint256 _newTotalTrust, uint256 _senderReputation) public returns (bool);
	function flagMissingReference(address _submission, address _missingReference) public returns (bool);
	function approveReference(address _submission, address _reference) public;
	function getTotalReferenceCount(address _submissionAddress) public constant returns (uint256);
	function peersJudged() public constant returns (uint256);
	function normalizedTrustInPeer(address _peer) public constant returns (uint256);
}