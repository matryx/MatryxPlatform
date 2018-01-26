pragma solidity ^0.4.18;

interface IMatryxSubmission
{
	function isAccessible(address _requester) public constant returns (bool);
	function getAuthor() constant public returns(address);
	function getName() constant public returns(string);
	function getReferences() constant public returns(address[]);
	function getContributors() constant public returns(address[]); 
	function getExternalAddress() constant public returns (bytes32);
	function getTimeSubmitted() constant public returns(uint256);
	function makeExternallyAccessibleDuringTournament() public;
	function updateName(string _name) public;
	function updateExternalAddress(bytes32 _externalAddress) public;
	function addReference(address _reference) public;
	function removeReference(uint256 _referenceIndex) public;
	function addContributor(address _contributor) public;
	function removeContributor(uint256 _contributorIndex) public;
	function setBalance(uint256 _bounty) public;
}