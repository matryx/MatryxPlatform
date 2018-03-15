pragma solidity ^0.4.18;

interface IMatryxSubmission
{
	function isAccessible(address _requester) public constant returns (bool);
	function getTitle() constant public returns (string);
	function getAuthor() constant public returns(address);
	function getReferences() constant public returns(address[]);
	function getContributors() constant public returns(address[]); 
	function getExternalAddress() constant public returns (bytes32);
	function getTimeSubmitted() constant public returns(uint256);
	function makeExternallyAccessibleDuringTournament() public;
	function updateTitle(string _title) public;
	function updateExternalAddress(bytes32 _externalAddress) public;
	function addReference(address _reference) public;
	function removeReference(uint256 _referenceIndex) public;
	function addContributor(address _contributor) public;
	function removeContributor(uint256 _contributorIndex) public;
	function getBalance() public returns (uint256);
	function getRound() public constant returns (address);
	function getTournament() public constant returns (address);
}