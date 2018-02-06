pragma solidity ^0.4.18;

interface IMatryxTournament
{
	function invokeSubmissionCreatedEvent(address _submissionAddress) public;
    function isEntrant(address _sender) public view returns (bool);
    function tournamentOpen() public view returns (bool);
    function roundIsOpen() public constant returns (bool);
    function getExternalAddress() public view returns (bytes32 _externalAddress);
    function currentRound() public constant returns (uint256 _currentRound, address _currentRoundAddress);
    function mySubmissions() public view returns (address[] _submissions);
    function submissionCount() public view returns (uint256 _submissionCount);
    function openTournament() public;
    function chooseWinner(uint256 _submissionIndex) public;
    function setNumberOfRounds(uint256 _newMaxRounds) public;
    function createRound(uint256 _bountyMTX) public returns (address _roundAddress);
    function startRound(uint256 _duration) public;
    function closeTournament(uint256 _submissionIndex) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool success);
    function getEntryFee() public view returns (uint256);
    function createSubmission(string _name, address _author, bytes32 _externalAddress, address[] _contributors, address[] _references, bool _publicallyAccessible) public returns (address _submissionAddress);
}