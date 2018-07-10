pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/LibConstruction.sol';

interface IMatryxRound
{
	//function removeSubmission(address _submissionAddress) public returns (bool);
	function getState() public view returns (uint256);
	function submissionIsAccessible(uint256 _index) public view returns (bool);
	function requesterIsContributor(address _requester) public view returns (bool);
	function setParticipantType(address _participantAddress, uint256 _type) public;
	function getStartTime() public view returns (uint256);
	function getEndTime() public view returns (uint256);
	function getBounty() public view returns (uint256);
	function getTokenAddress() public view returns (address);
	function getSubmissions() public view returns (address[] _submissions);
	function getSubmissionAuthor(uint256 _index) public view returns (address) ;
	function getBalance(address _submissionAddress) public view returns (uint256);
	function submissionsChosen() public view returns (bool);
	function getWinningSubmissionAddresses() public view returns (address[]);
	function numberOfSubmissions() public view returns (uint256);
	function getParticipantType(address _participant) public view returns (uint256);
	function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public;
	function transferToTournament(uint256 _amount) public;
	function selectWinningSubmissions(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public;
	function transferAllToWinners(uint256 _tournamentBalance) public;
	function startNow() public;
	function closeRound() public;
	function becomeEntrant(address _entrant) public;
	function becomeNonentrant(address _entrant) public;
	//function awardBounty(address _submissionAddress, uint256 _remainingBounty) public;
	function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references,address _author, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
	function transferBountyToTournament() public returns (uint256);
}