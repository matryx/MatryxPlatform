pragma solidity ^0.4.18;

interface IMatryxTournament
{
	function invokeSubmissionCreatedEvent(address _submissionAddress) public;
    function removeSubmission(address _submissionAddress, address _author) public returns (bool);
    function isEntrant(address _sender) public view returns (bool);
    function isOpen() public view returns (bool);
    function isInReview() public view returns (bool);
    function roundIsOpen() public constant returns (bool);
    function getPlatform() public view returns (address _platformAddress);
    function getExternalAddress() public view returns (bytes _externalAddress);
    function currentRound() public constant returns (uint256 _currentRound, address _currentRoundAddress);
    function mySubmissions() public view returns (address[]);
    function submissionCount() public view returns (uint256 _submissionCount);
    function entrantCount() public view returns (uint256 _entrantCount);
    function setTitle(string _title) public;
    function setExternalAddress(bytes _externalAddress) public;
    function setEntryFee(uint256 _entryFee) public;
    function setNumberOfRounds(uint256 _newMaxRounds) public;
    function setCategory(string _category) public;
    function chooseWinner(address _submissionAddress) public;
    function createRound(uint256 _bountyMTX) public returns (address _roundAddress) ;
    function startRound(uint256 _duration, uint256 _reviewPeriod) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool success);
    function getEntryFee() public view returns (uint256);
    function createSubmission(string _title, address _owner, bytes _externalAddress, address[] _contributors, uint128[] contributorRewardDistribution, address[] _references) public returns (address _submissionAddress);
}