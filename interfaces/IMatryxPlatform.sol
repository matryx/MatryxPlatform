pragma solidity ^0.4.18;

interface IMatryxPlatform
{
	function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public;
	function invokeTournamentClosedEvent(address _tournamentAddress, uint256 _finalRoundNumber, address _winningSubmissionAddress, uint256 _MTXReward) public;
	function prepareBalance(uint256 _toIgnore) public;
	function balanceIsNonZero() public view returns (bool);
	function getBalance() public constant returns (uint256);
	function handleReferencesForSubmission(address _submissionAddress, address[] _references) public returns (bool);
	function handleReferenceForSubmission(address _reference) public returns (bool);
	function enterTournament(address _tournamentAddress) public returns (bool _success);
	function createTournament(string _discipline, string _tournamentName, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee, uint256 _reviewPeriod) public returns (address _tournamentAddress);
	function updateSubmissions(address _author, address _submission) public;
	function removeSubmission(address _submissionAddress, address _tournamentAddress) public returns (bool);
	function isPeer(address _peerAddress) public constant returns (bool);
	function hasPeer(address _sender) public returns (bool);
	function peerExistsAndOwnsSubmission(address _peer, address _reference) public returns (bool);
	function peerAddress(address _sender) public constant returns (address);
	function isSubmission(address _submissionAddress) public constant returns (bool);
	function getTournament_IsMine(address _tournamentAddress) public constant returns (bool _isMine);
	function tournamentCount() public constant returns (uint256 _tournamentCount);
	function getTokenAddress() public constant returns (address);
	function myTournaments() public constant returns (address[]);
	function mySubmissions() public constant returns (address[]);
}