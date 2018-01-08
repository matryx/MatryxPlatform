pragma solidity ^0.4.18;

import './MatryxOracleMessenger.sol';
import './Tournament.sol';
import './Ownable.sol';

/// @title MatryxPlatform - The Matryx platform contract.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxPlatform is MatryxOracleMessenger {

  address[] public allTournaments;
  mapping(address=>bool) tournamentExists;

  /*
   * Events
   */

  event TournamentCreated(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentOpened(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentClosed(address _tournamentAddress, uint256 _finalRoundNumber, uint256 _submissionIndex_winner);

  /// @dev Allows tournaments to invoke tournamentOpened events on the platform.
  /// @param _owner Owner of the tournament.
  /// @param _tournamentAddress Address of the tournament.
  /// @param _tournamentName Name of the tournament.
  /// @param _externalAddress External address of the tournament.
  /// @param _MTXReward Reward for winning the tournament.
  /// @param _entryFee Fee for entering into the tournament.
  function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyTournament(msg.sender)
  {
    TournamentOpened(_owner, _tournamentAddress, _tournamentName, _externalAddress, _MTXReward, _entryFee);
  }

  /// @dev Allows tournaments to invoke tournamentClosed events on the platform.
  /// @param _finalRoundNumber Index of the round containing the winning submission.
  /// @param _submissionIndex_winner Index of the winning submission.
  function invokeTournamentClosedEvent(uint256 _finalRoundNumber, uint256 _submissionIndex_winner) public onlyTournament(msg.sender)
  {
    TournamentClosed(msg.sender, _finalRoundNumber, _submissionIndex_winner);
  }

  /* 
   * Modifiers
   */

  modifier onlyTournament(address _sender)
  {
    require(tournamentExists[_sender]);
    _;
  }

  modifier onlyTournamentOwner(address _tournament)
  {
    require(getTournament_IsMine(_tournament));
    _;
  }

  modifier ifTournamentExists(address _tournamentAddress)
  {
    require(tournamentExists[_tournamentAddress]);
    _;
  }

  modifier onlyEntrant(address _tournamentAddress, address _sender)
  {
    require(Tournament(_tournamentAddress).isEntrant(_sender));
    _;
  }

  modifier whileTournamentOpen(address _tournamentAddress)
  {
    require(Tournament(_tournamentAddress).tournamentOpen());
    _;
  }

  modifier whileRoundOpen(address _tournamentAddress)
  {
    require(Tournament(_tournamentAddress).roundIsOpen());
    _;
  }

  /* 
   * MTX Balance Methods
   */

  /// @dev Prepares the user's MTX balance, allowing them to use the platform.
  /// @param _toIgnore Request bytes (deprecated).
  function prepareBalance(uint256 _toIgnore) public
  {   
      // Make sure that the user has not already attempted to prepare their balance
      uint256 qID = fromQuerierToQueryID[msg.sender];
      uint256 queryResponse = queryResponses[qID];
      require(queryResponse == 0x0);

      this.Query(bytes32(_toIgnore), msg.sender);
  }

  /// @dev Returns whether or not the user can use the platform.
  /// @return Whether or not user has a positive balance.
  function balanceIsNonZero() public view returns (bool)
  {
      uint balance = latestResponseFromOracle(msg.sender);
      bool nonZero = balance > 0;
      return nonZero;
  }

  // Returns the user's balance

  /// @dev Returns the user's balance
  /// @return Sender's MTX balance.
  function getBalance() public constant returns (uint256)
  {
      uint256 balance = latestResponseFromOracle(msg.sender);
      return balance;
  }

  /* 
   * Tournament Entry Methods
   */

  /// @dev Enter the user into a tournament and charge the entry fee.
  /// @param _tournamentAddress Address of the tournament to enter into.
  /// @return _success Whether or not user was successfully entered into the tournament.
  function enterTournament(address _tournamentAddress) public returns (bool _success)
  {
      Tournament tournament = Tournament(_tournamentAddress);
      // TODO: Charge the user the MTX entry fee.
      bool success = tournament.enterUserInTournament(msg.sender);
      return success;
  }

  /* 
   * Tournament Admin Methods
   */

  /// @dev Create a new tournament.
  /// @param _tournamentName Name of the new tournament.
  /// @param _externalAddress Off-chain content hash of tournament details (ipfs hash)
  /// @param _MTXReward Total tournament reward in MTX.
  /// @param _entryFee Fee to charge participant upon entering into tournament.
  /// @return _tournamentAddress Address of the newly created tournament
  function createTournament(string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyOwner returns (address _tournamentAddress)
  {
    address newTournament = new Tournament(msg.sender, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    TournamentCreated(msg.sender, newTournament, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    
    // update data structures
    allTournaments.push(newTournament);
    tournamentExists[newTournament] = true;

    return newTournament;
  }

  /// @dev Open a tournament to submissions.
  /// @param _tournamentAddress Address of the tournament to open.
  /// @return _tournamentAddress Address of the newly created tournament
  function openTournament(address _tournamentAddress) public onlyTournamentOwner(_tournamentAddress)
  {
    Tournament(_tournamentAddress).openTournament();
  }

  /// @dev Closes a tournament to submissions.
  /// @param _tournamentAddress Address of tournament to close.
  /// @param _submissionIndex Index of winning submission.
  function closeTournament(address _tournamentAddress, uint256 _submissionIndex) public ifTournamentExists(_tournamentAddress) onlyTournamentOwner(_tournamentAddress)
  {
    Tournament tournament = Tournament(_tournamentAddress);
    tournament.closeTournament(_submissionIndex);
    uint256 finalRoundNumber = tournament.currentRound();
    TournamentClosed(_tournamentAddress, finalRoundNumber, _submissionIndex);
  }

  /*
   * Access Control Methods
   */

  /// @dev Returns whether or not the given tournament belongs to the sender.
  /// @param _tournamentAddress Address of the tournament to check.
  /// @return _isMine Whether or not the tournament belongs to the sender.
  function getTournament_IsMine(address _tournamentAddress) public constant returns (bool _isMine)
  {
    require(tournamentExists[_tournamentAddress]);
    return Tournament(_tournamentAddress).getOwner() == msg.sender;
  }

  /// @dev Returns whether or not a tournament is open.
  /// @param _tournamentAddress Address of the tournament to check.
  /// @return _isOpen Whether or not the tournament is open
  function getTournament_IsOpen(address _tournamentAddress) public ifTournamentExists(_tournamentAddress) view returns (bool _isOpen)
  {
      return Tournament(_tournamentAddress).tournamentOpen();
  }

  /// @dev Returns whether or not a round of the tournament is open.
  /// @param _tournamentAddress Address of the tournament to check.
  /// @return _roundOpen Whether or not a round is open on this tournament.
  function getTournament_RoundOpen(address _tournamentAddress) public ifTournamentExists(_tournamentAddress) view returns (bool _roundOpen)
  {
    return Tournament(_tournamentAddress).roundIsOpen();
  }

  /* 
   * Tournament Getters
   */

  /// @dev Returns the total number of tournaments
  /// @return _tournamentCount Total number of tournaments.
  function tournamentCount() public constant returns (uint256 _tournamentCount)
  {
      return allTournaments.length;
  }

  /// @dev Returns the external address of a tournament
  /// @param _tournamentAddress Address of the tournament to use.
  /// @return _externalAddress External address of the tournament.
  function getTournament_ExternalAddress(address _tournamentAddress) public ifTournamentExists(_tournamentAddress) view returns (bytes32 _externalAddress)
  {
      return Tournament(_tournamentAddress).getExternalAddress();
  }

  /* 
   * Round Getters
   */

  /// @dev Returns the current round number.
  /// @param _tournamentAddress Address of the tournament to use.
  /// @return _currentRound Number of the current round.
  function getTournament_CurrentRound(address _tournamentAddress) public ifTournamentExists(_tournamentAddress) view returns (uint256 _currentRound)
  {
      return Tournament(_tournamentAddress).currentRound();
  }

  /* 
   * Submission Methods
   */

  /// @dev Create a submission under the given tournament.
  /// @param _tournamentAddress Address of the tournament to submit to.
  /// @param _name Name of the submission
  /// @param _externalAddress Off-chain content hash of submission (ipfs hash)
  /// @param _references Addresses of submissions referenced in creating this submission
  /// @param _contributors Contributors to this submission.
  /// @return (_roundIndex, _submissionIndex) Location of this submission.
  function createSubmission(address _tournamentAddress, string _name, bytes32 _externalAddress, address[] _references, address[] _contributors) public ifTournamentExists(_tournamentAddress) onlyEntrant(_tournamentAddress, msg.sender) whileTournamentOpen(_tournamentAddress) whileRoundOpen(_tournamentAddress) returns (uint256 _roundIndex, uint256 _submissionIndex)
  {
    return Tournament(_tournamentAddress).createSubmission(_name, _externalAddress, _references, _contributors);
  }

  /// @dev Returns the number of submissions under a given tournament.
  /// @param _tournamentAddress Address of the tournament to check.
  /// @return _submissionCount Number of submissions.
  function submissionCount(address _tournamentAddress) public view returns (uint256 _submissionCount)
  {
      return Tournament(_tournamentAddress).submissionCount();
  }

}