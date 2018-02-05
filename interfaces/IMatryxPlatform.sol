pragma solidity ^0.4.18;

interface IMatryxPlatform
{
	function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public;
	function invokeTournamentClosedEvent(address _tournamentAddress, uint256 _finalRoundNumber, uint256 _winningSubmissionIndex) public;
	function prepareBalance(uint256 _toIgnore) public;
	function balanceIsNonZero() public view returns (bool);
	function getBalance() public constant returns (uint256);
	function enterTournament(address _tournamentAddress) public returns (bool _success);
	function createTournament(string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public returns (address _tournamentAddress);
	function updateMySubmissions(address _author, address _submission) public;
	function getTournament_IsMine(address _tournamentAddress) public constant returns (bool _isMine);
	function tournamentCount() public constant returns (uint256 _tournamentCount);
	function myTournaments() public constant returns (address[]);
	function mySubmissions() public constant returns (address[]);
}