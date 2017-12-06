pragma solidity ^0.4.18;

//Import all necessary contracts
import './MatryxOracleMessenger.sol';
import './Tournament.sol';
import './Ownable.sol';

//import submissions contract

//Initialize the contract
contract MatryxPlatformAlphaMain is MatryxOracleMessenger{

  event TournamentCreated(address tournamentOwner, address tournamentAddress, string tournamentName, bytes32  externalAddress, 
    uint256  startRoundTime, uint256  roundEndTime, uint256  reviewPeriod, uint256  endOfTournamentTime,
    uint bountyMTX, uint currentRound, uint maxRounds);

	//Initialize variables
  address[] public allTournaments; //convert into a map?
  mapping(address=>bool) tournamentExists;
  //TODO for when anyone can submit a tournament
  // mapping(address => TournamentSubmitters) public submitters

  // ----------------- MTX Balance Methods -----------------

  // Prepares the user's balance (allowing them to use the platform)
  function prepareBalance(uint256 toIgnore) public
  {
      this.Query(bytes32(toIgnore), msg.sender);
  }

  // Returns whether or not the user can use the platform
  function balanceIsNonZero() public view returns (bool)
  {
      uint balance = latestResponseFromOracle(msg.sender);
      bool nonZero = balance > 0;
      return nonZero;
  }

  // Returns the user's balance
  function getBalance() public constant returns (uint256)
  {
      uint256 balance = latestResponseFromOracle(msg.sender);
      return balance;
  }

  // ----------------- Tournament Info Methods -----------------

  // Gets a tournament by its address
  function tournamentByAddress(address tournamentAddress) public returns (bytes32)
  {
      require(tournamentExists[tournamentAddress]);
      Tournament t = Tournament(tournamentAddress);
      bytes32 externalAddress = t.getExternalAddress();

      return (externalAddress);
  }

  // Gets the total number of tournaments
  function tournamentCount() public constant returns (uint256)
  {
      return allTournaments.length;
  }

  // ----------------- Tournament Entry Methods -----------------

  // A function allowing the user to make submissions.
  // This function charges the user MTX as an entry fee
  // set by the tournament creator.
  function enterTournament(address _tournamentAddress) public returns (address _submissionViewer)
  {
      Tournament tournament = Tournament(_tournamentAddress);
      // TODO: Charge the user the MTX entry fee.
      address submissionViewerAddress = tournament.enterUserInTournament(msg.sender);
      return submissionViewerAddress;
  }

  // ----------------- Tournament Editing Methods -----------------
  
  //Create a new tournament if you own the contract ie: just Matryx Team for now.
  function createTournament(string _tournamentName, bytes32 _externalAddress, uint256 _tournamentStartTime, uint256 _roundStartTime, uint256 _roundEndTime, uint256 _reviewPeriod, uint256 _endOfTournamentTime, uint256 _MTXReward, uint256 _entryFee, uint256 _currentRound, uint256 _maxRounds) public onlyOwner returns (address)
  {
    address newTournament = new Tournament(msg.sender, _tournamentName, _externalAddress, _tournamentStartTime, _roundStartTime, _roundEndTime, _reviewPeriod, _endOfTournamentTime, _MTXReward, _entryFee, _currentRound, _maxRounds);
    TournamentCreated(msg.sender, newTournament, _tournamentName, _externalAddress, _roundStartTime, _roundEndTime, _reviewPeriod, _endOfTournamentTime, _MTXReward, _currentRound, _maxRounds);
    allTournaments.push(newTournament);
  }

}