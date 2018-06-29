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
    function getTitle() public view returns (bytes32[3] _title);
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash);
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress);
    function mySubmissions() public view returns (address[]);
    function submissionCount() public view returns (uint256 _submissionCount);
    function entrantCount() public view returns (uint256 _entrantCount);
    function update(string _category, LibConstruction.TournamentModificationData tournamentData);
    function updateTitle(bytes32[3] _title) public;
    function updateDescriptionHash(bytes32[2] _externalAddress) public;
    function updateEntryFee(uint256 _entryFee) public;
    function updateCategory(string _category) public;
    function selectWinners(address[] _submissionAddresses, uint256[] _rewardDistribution, uint256 _selectWinnerAction) public;
    function editNextRound(LibConstruction.RoundData _roundData) public;
    function jumpToNextRound() public;
    function stopTournament() public;
    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public;
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress);
    function enterUserInTournament(address _entrantAddress) public returns (bool success);
    function getEntryFee() public view returns (uint256);
    function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
    function withdraw() public;
    function pullRemainingBountyIntoRound() public;
}