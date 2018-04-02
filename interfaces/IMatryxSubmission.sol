pragma solidity ^0.4.18;

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
	function makeExternallyAccessibleDuringTournament() public;
	function updateTitle(string _title) public ;
	function updateExternalAddress(bytes _externalAddress) public;
	function addReference(address _reference) public ;
	function addressIsFlagged(address _reference) public constant returns (bool, bool);
	function removeReference(address _reference) public;
	function receiveReferenceRequest() public;
	function cancelReferenceRequest() public;
	function approveReference(address _reference) public;
	function removeReferenceApproval(address _reference) public;
	function flagMissingReference(address _reference) public;
	function removeMissingReferenceFlag(address _reference) public;
	function addContributor(address _contributor, uint128 _bountyAllocation) public;
	function removeContributor(uint256 _contributorIndex) public ;
	function getBalance() public returns (uint256);
	function withdrawReward(address _recipient) public;
	function getTransferAmount() public constant returns (uint256);
	function deleteSubmission() public;
}