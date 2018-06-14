pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/LibConstruction.sol';

interface IMatryxSubmission {
	function getTournament() public constant returns (address);
	function getRound() public constant returns (address);
	function isAccessible(address _requester) public constant returns (bool);
	function getTitle() public constant returns(string);
	function getAuthor() public constant returns(address);
	function getExternalAddress() public constant returns (bytes);
	function getReferences() public constant returns(address[]);
	function getContributors() public constant returns(address[]);
	function getTimeSubmitted() public constant returns(uint256);
	function getTimeUpdated() public constant returns(uint256);
	function updateAll(address[] _contributorsToAdd, uint128[] _contributorRewardDistribution, address[] _contributorsToRemove,LibConstruction.SubmissionModificationData _data);
	function setIsPublic(bool _public) public;
	function updateTitle(string _title) public ;
	function updateExternalAddress(bytes _externalAddress) public;
	function addReference(address _reference) public ;
	function removeReference(address _reference) public;
	function receiveReferenceRequest() public;
	function cancelReferenceRequest() public;
	function approveReference(address _reference) public;
	function removeReferenceApproval(address _reference) public;
	function flagMissingReference(address _reference) public;
	function removeMissingReferenceFlag(address _reference) public;
	function addContributor(address _contributor, uint128 _bountyAllocation) public;
	function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public;
	function removeContributor(uint256 _contributorIndex) public;
	function removeContributors(address[] _contributorsToRemove) public;
	function getBalance() public returns (uint256);
	function withdrawReward(address _recipient) public;
	function getTransferAmount() public constant returns (uint256);
	//function deleteSubmission() public;
}