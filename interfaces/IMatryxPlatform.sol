pragma solidity ^0.4.18;

interface IMatryxPlatform
{
	function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes _externalAddress, uint256 _MTXReward, uint256 _entryFee) public;
	function invokeTournamentClosedEvent(address _tournamentAddress, uint256 _finalRoundNumber, address _winningSubmissionAddress, uint256 _MTXReward) public;
	function prepareBalance(uint256 _toIgnore) public;
	function balanceIsNonZero() public view returns (bool);
	function getBalance() public constant returns (uint256);
	function handleReferenceRequestsForSubmission(address _submissionAddress, address[] _references) public returns (bool) ;
	function handleReferenceRequestForSubmission(address _reference) public returns (bool);
	function handleCancelledReferenceRequestForSubmission(address _reference) public returns (bool);
	function updateSubmissions(address _owner, address _submission) public;
	function removeSubmission(address _submissionAddress, address _tournamentAddress) public returns (bool);
	function enterTournament(address _tournamentAddress) public returns (bool _success);
	function createTournament(string _category, string _tournamentName, bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee, uint256 _reviewPeriod) public returns (address _tournamentAddress);
	function createPeer() public returns (address);
	function isPeer(address _peerAddress) public constant returns (bool);
	function hasPeer(address _sender) public constant returns (bool);
	function peerExistsAndOwnsSubmission(address _peer, address _reference) public constant returns (bool);
	function peerAddress(address _sender) public constant returns (address);
	function isSubmission(address _submissionAddress) public constant returns (bool);
	function getTournament_IsMine(address _tournamentAddress) public constant returns (bool _isMine);
	function setSubmissionGratitude(uint256 _gratitude) public;
	function getTokenAddress() public constant returns (address);
	function getSubmissionTrustLibrary() public constant returns (address);
	function getRoundLibAddress() public constant returns (address);
	function getSubmissionGratitude() public constant returns (uint256);
	function myTournaments() public constant returns (address[]);
	function mySubmissions() public constant returns (address[]);
	function tournamentCount() public constant returns (uint256 _tournamentCount);
	function getTournamentAtIndex(uint256 _index) public constant returns (address _tournamentAddress);
}