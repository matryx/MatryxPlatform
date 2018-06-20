pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/LibConstruction.sol';

interface IMatryxRound
{
	//function removeSubmission(address _submissionAddress) public returns (bool);
	function getState() public view returns (uint256);
	function submissionIsAccessible(uint256 _index) public constant returns (bool);
	function requesterIsContributor(address _requester) public constant returns (bool);
	function setParticipantType(address _participantAddress, uint256 _type) public;
	function getBounty() public constant returns (uint256);
	function getTokenAddress() public constant returns (address);
	function getSubmissions() public constant returns (address[] _submissions);
	function getSubmissionAuthor(uint256 _index) public constant returns (address) ;
	function getBalance(address _submissionAddress) public constant returns (uint256);
	function submissionsChosen() public constant returns (bool);
	function getWinningSubmissionAddresses() public constant returns (address[]);
	function numberOfSubmissions() public constant returns (uint256);
	function chooseWinningSubmissions(address[] _submissionAddresses, uint256[] _rewardDistribution) public;
	//function awardBounty(address _submissionAddress, uint256 _remainingBounty) public;
	function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references,address _author, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
	function liquidate() public;
}