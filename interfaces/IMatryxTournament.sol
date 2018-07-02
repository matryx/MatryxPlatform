pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../libraries/LibConstruction.sol';

interface IMatryxTournament
{
    function invokeSubmissionCreatedEvent(address _submissionAddress) public;
    function removeSubmission(address _submissionAddress, address _author) public returns (bool);
    function isEntrant(address _sender) public view returns (bool);
    function getState() public view returns (uint256);
    function getPlatform() public view returns (address _platformAddress);
    function getData() public view returns (LibConstruction.TournamentData _data);
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress);
    function getBounty() public returns (uint256 _tournamentBounty);
    function getBalance() public returns (uint256 _tournamentBalance);
    function mySubmissions() public view returns (address[]);
    function submissionCount() public view returns (uint256 _submissionCount);
    function entrantCount() public view returns (uint256 _entrantCount);
    function update(LibConstruction.TournamentModificationData tournamentData, string _category) public;
    function selectWinners(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public;
    function editGhostRound(LibConstruction.RoundData _roundData) public;
    function allocateMoreToRound(uint256 _mtxAllocation) public;
    function jumpToNextRound() public;
    function stopTournament() public;
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress);
    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool _success);
    function getEntryFee() public view returns (uint256);
    function collectMyEntryFee() public;
    function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
    function withdrawFromAbandoned() public;
}