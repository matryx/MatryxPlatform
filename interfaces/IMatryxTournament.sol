pragma solidity ^0.4.18;

interface IMatryxTournament
{
	function invokeSubmissionCreatedEvent(address _submissionAddress) public;
    function removeSubmission(address _submissionAddress, address _author) public returns (bool);
    function isEntrant(address _sender) public view returns (bool);
    function getState() public view returns (uint256);
    function getPlatform() public view returns (address _platformAddress);
    function getTitle() public view returns (string _title);
    function getExternalAddress() public view returns (bytes _externalAddress);
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress);
    function mySubmissions() public view returns (address[]);
    function submissionCount() public view returns (uint256 _submissionCount);
    function entrantCount() public view returns (uint256 _entrantCount);
    function setTitle(string _title) public;
    function setExternalAddress(bytes _externalAddress) public;
    function setEntryFee(uint256 _entryFee) public;
    function setCategory(string _category) public;
    function closeRound(address _submissionAddress, uint256 _end, uint256 _reviewDuration, uint256 _bountyMTX) public;
    function closeTournament(address _submissionAddress) public;
    function createRound(uint256 _start, uint256 _end, uint256 _reviewDuration, uint256 _bountyMTX) public returns (address _roundAddress) ;
    function enterUserInTournament(address _entrantAddress) public returns (bool success);
    function getEntryFee() public view returns (uint256);
    function createSubmission(string _title, address _owner, bytes _externalAddress, address[] _contributors, uint128[] contributorRewardDistribution, address[] _references) public returns (address _submissionAddress);
}