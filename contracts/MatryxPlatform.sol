pragma solidity ^0.4.18;

//Import all necessary contracts
import './MatryxOracleMessenger.sol';
import './Tournament.sol';
import './Ownable.sol';

//import submissions contract

//Initialize the contract
contract MatryxPlatform is MatryxOracleMessenger {

  //Initialize variables
  address[] public allTournaments; //convert into a map?
  mapping(address=>bool) tournamentExists;
  //TODO for when anyone can submit a tournament
  // mapping(address => TournamentSubmitters) public submitters

  // ----------------- Events ------------------------------

  event TournamentCreated(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentOpened(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentClosed(address _tournamentAddress, address _winningSubmissionAddress);

  function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyTournament(msg.sender)
  {
    TournamentOpened(_owner, _tournamentAddress, _tournamentName, _externalAddress, _MTXReward, _entryFee);
  }

  function invokeTournamentClosedEvent(address _tournamentAddress, address _winningSubmissionAddress) public onlyTournament(msg.sender)
  {
    TournamentClosed(_tournamentAddress, _winningSubmissionAddress);
  }

  // ----------------- Modifiers ---------------------------

  modifier onlyTournament(address _sender)
  {
    require(tournamentExists[_sender]);
    _;
  }

  modifier onlyTournamentOwner(address _tournament)
  {
    require(tournamentIsMine(_tournament));
    _;
  }

  // ----------------- MTX Balance Methods -----------------

  // Prepares the user's balance (allowing them to use the platform)
  function prepareBalance(uint256 toIgnore) public
  {   
      // Make sure that the user has not already attempted to prepare their balance
      uint256 qID = fromQuerierToQueryID[msg.sender];
      uint256 queryResponse = queryResponses[qID];
      require(queryResponse == 0x0);

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
  function tournamentByAddress(address tournamentAddress) public view returns (bytes32)
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

  function tournamentIsMine(address _tournamentAddress) public constant returns (bool)
  {
    require(tournamentExists[_tournamentAddress]);
    return Tournament(_tournamentAddress).getOwner() == msg.sender;
  }

  // ----------------- Tournament Entry Methods -----------------

  // A function allowing the user to make submissions.
  // This function charges the user MTX as an entry fee
  // set by the tournament creator.
  function enterTournament(address _tournamentAddress) public returns (bool _success)
  {
      Tournament tournament = Tournament(_tournamentAddress);
      // TODO: Charge the user the MTX entry fee.
      bool success = tournament.enterUserInTournament(msg.sender);
      return success;
  }

  // ----------------- Tournament Editing Methods -----------------
  
  //Create a new tournament if you own the contract ie: just Matryx Team for now.
  function createTournament(string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyOwner returns (address)
  {
    address newTournament = new Tournament(msg.sender, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    TournamentCreated(msg.sender, newTournament, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    
    // update data structures
    allTournaments.push(newTournament);
    tournamentExists[newTournament] = true;
  }

  function openTournament(address _tournamentAddress, uint256 _MTXReward) public onlyTournamentOwner(_tournamentAddress)
  {
    Tournament(_tournamentAddress).openTournament(_MTXReward);
  }
}