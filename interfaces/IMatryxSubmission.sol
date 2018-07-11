pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/LibConstruction.sol';

interface IMatryxSubmission {
	function getTournament() public view returns (address);
	function getRound() public view returns (address);
	function isAccessible(address _requester) public view returns (bool);
	function getTitle() public view returns(string);
	function getAuthor() public view returns(address);
	function getDescriptionHash() public view returns (bytes);
    function getFileHash() public view returns (bytes);
	function getReferences() public view returns(address[]);
	function getContributors() public view returns(address[]);
	function getTimeSubmitted() public view returns(uint256);
	function getTimeUpdated() public view returns(uint256);
	function update(address[] _contributorsToAdd, uint128[] _contributorRewardDistribution, address[] _contributorsToRemove,LibConstruction.SubmissionModificationData _data);
	function updateIsPublic(bool _public) public;
	function updateTitle(string _title) public ;
	function updateDescription(bytes _externalAddress) public;
    function updateFile(bytes _fileHash) public;
	function addToWinnings(uint256 _amount) public;
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
	function getTransferAmount() public view returns (uint256);
	//function deleteSubmission() public;
}