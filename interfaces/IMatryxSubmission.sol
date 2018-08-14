pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";

interface IMatryxSubmission {
  function getTournament() public view returns (address);
  function getRound() public view returns (address);
  function getSubmissionOwner() public view returns (address);
  function isAccessible(address _requester) public view returns (bool);
  function getData() public view returns(LibConstruction.SubmissionData _data);
  function getTitle() public view returns(bytes32[3]);
  function getDescriptionHash() public view returns (bytes32[2]);
  function getFileHash() public view returns (bytes32[2]);
  function getPermittedDownloaders() public view returns (address[]);
  function getReferences() public view returns(address[]);
  function getContributors() public view returns(address[]);
  function getContributorRewardDistribution() public view returns (uint256[]);
  function getTimeSubmitted() public view returns(uint256);
  function getTimeUpdated() public view returns(uint256);
  function unlockFile() public;
  function updateData(LibConstruction.SubmissionModificationData _modificationData) public;
  function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public;
  function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public;
  function addToWinnings(uint256 _amount) public;
  function flagMissingReference(address _reference) public;
  function removeMissingReferenceFlag(address _reference) public;
  function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public;
  function getBalance() public view returns (uint256);
  function withdrawReward() public;
  function myReward() public view returns (uint256);
  //function deleteSubmission() public;
}
