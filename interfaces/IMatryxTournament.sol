pragma solidity ^0.4.18;

interface IMatryxTournament
{
	function invokeSubmissionCreatedEvent(uint256 _submissionIndex) public;
    function isCreator(address _sender) public view returns (bool);
    function isEntrant(address _sender) public view returns (bool);
    function tournamentOpen() public view returns (bool);
    function roundIsOpen() public constant returns (bool);
    function getExternalAddress() public view returns (bytes32 _externalAddress);
    function currentRound() public constant returns (uint256 _currentRound, address _currentRoundAddress);
    function mySubmissions() public view returns (uint256[] _roundIndices, uint256[] _submissionIndices);
    function submissionsByContributorAddress(address _sender) public view returns (uint256[] _roundIndices, uint256[] _submissionIndices);
    function submissionCount() public view returns (uint256 _submissionCount);
    function openTournament() public;
    function chooseWinner(uint256 _submissionIndex) public;
    function createRound(uint256 _bountyMTX) public returns (address _roundAddress);
    function startRound(uint256 _duration) public;
    function closeTournament(uint256 _submissionIndex) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool success);
    function getEntryFee() public view returns (uint256);
    function createSubmission(string _name, address _author, bytes32 _externalAddress, address[] _contributors, address[] _references, bool _publicallyAccessible) public returns (uint256 _submissionIndex);
}