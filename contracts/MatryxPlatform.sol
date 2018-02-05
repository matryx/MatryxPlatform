pragma solidity ^0.4.18;

import './MatryxOracleMessenger.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/factories/IMatryxTournamentFactory.sol';
import '../interfaces/IMatryxTournament.sol';
import './Ownable.sol';

/// @title MatryxPlatform - The Matryx platform contract.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxPlatform is MatryxOracleMessenger, IMatryxPlatform {

  address matryxTournamentFactoryAddress;
  address[] public allTournaments;
  mapping(address=>bool) tournamentExists;
  mapping(address=>address[]) entrantToTournamentArray;
  mapping(address=>address[]) authorToSubmissionArray;

  function MatryxPlatform(address _matryxTournamentFactoryAddress) public
  {
    matryxTournamentFactoryAddress = _matryxTournamentFactoryAddress;
  }

  /*
   * Events
   */

  event TournamentCreated(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentOpened(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentClosed(address _tournamentAddress, uint256 _finalRoundNumber, uint256 _winningSubmissionIndex);
  event QueryID(string queryID);
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
  /// @param _tournamentAddress Address of the tournament.
  /// @param _finalRoundNumber Index of the round containing the winning submission.
  /// @param _winningSubmissionIndex Index of the winning submission.
  function invokeTournamentClosedEvent(address _tournamentAddress, uint256 _finalRoundNumber, uint256 _winningSubmissionIndex) public onlyTournament(msg.sender)
  {
    TournamentClosed(_tournamentAddress, _finalRoundNumber, _winningSubmissionIndex);
  }

  /* 
   * Modifiers
   */

  modifier onlyTournament(address _sender)
  {
    require(tournamentExists[_sender]);
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
      return balance != 0;
  }

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
      IMatryxTournament tournament = IMatryxTournament(_tournamentAddress);
      // TODO: Charge the user the MTX entry fee.
      bool success = tournament.enterUserInTournament(msg.sender);
      if(success)
      {
        updateMyTournaments(msg.sender, _tournamentAddress);
      }
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
  function createTournament(string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public returns (address _tournamentAddress)
  {
    IMatryxTournamentFactory tournamentFactory = IMatryxTournamentFactory(matryxTournamentFactoryAddress);
    address newTournament = tournamentFactory.createTournament(msg.sender, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    TournamentCreated(msg.sender, newTournament, _tournamentName, _externalAddress, _MTXReward, _entryFee);
    
    // update data structures
    allTournaments.push(newTournament);
    tournamentExists[newTournament] = true;

    return newTournament;
  }

  function updateMyTournaments(address _author, address _tournament) internal
  {
    entrantToTournamentArray[_author].push(_tournament);
  }

  function updateMySubmissions(address _author, address _submission) public onlyTournament(msg.sender)
  {
    authorToSubmissionArray[_author].push(_submission);
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
    Ownable tournament = Ownable(_tournamentAddress);
    return (tournament.getOwner() == msg.sender);
  }

  /// @dev Returns the total number of tournaments
  /// @return _tournamentCount Total number of tournaments.
  function tournamentCount() public constant returns (uint256 _tournamentCount)
  {
      return allTournaments.length;
  }

  function getTournamentAtIndex(uint256 _index) public constant returns (address _tournamentAddress)
  {
    require(_index >= 0);
    require(_index < allTournaments.length);
    return allTournaments[_index];
  }

  /*
   * Getter Methods
   */

   /// @dev Returns addresses for submissions the sender has created.
   /// @return Address array representing submissions.
   function myTournaments() public constant returns (address[])
   {
      return entrantToTournamentArray[msg.sender];
   }

   function mySubmissions() public constant returns (address[])
   {
    return authorToSubmissionArray[msg.sender];
   }
}