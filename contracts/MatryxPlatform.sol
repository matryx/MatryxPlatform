pragma solidity ^0.4.18;

import './MatryxOracleMessenger.sol';
import '../interfaces/IMatryxToken.sol';
import '../interfaces/IMatryxPeer.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/factories/IMatryxPeerFactory.sol';
import '../interfaces/factories/IMatryxTournamentFactory.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

/// @title MatryxPlatform - The Matryx platform contract.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxPlatform is MatryxOracleMessenger, IMatryxPlatform {

  address public matryxTokenAddress;
  address matryxPeerFactoryAddress;
  address matryxTournamentFactoryAddress;
  address[] public allTournaments;
  // TODO: condense bool mappings using struct
  mapping(address=>bool) peerExists;
  mapping(address=>address) ownerToPeer;
  mapping(address=>mapping(address=>bool)) peerToOwnsSubmission;
  mapping(address=>bool) tournamentExists;
  mapping(address=>bool) submissionExists;

  mapping(address=>address[]) entrantToTournamentArray;
  mapping(address=>address[]) authorToSubmissionArray;
  mapping(address=>mapping(address=>uint256_optional))  authorToSubmissionToSubmissionIndex;

  function MatryxPlatform(address _matryxTokenAddress, address _matryxPeerFactoryAddress, address _matryxTournamentFactoryAddress) public
  {
    matryxTokenAddress = _matryxTokenAddress;
    matryxPeerFactoryAddress = _matryxPeerFactoryAddress;
    matryxTournamentFactoryAddress = _matryxTournamentFactoryAddress;
  }

  /*
   * Structs
   */

  struct uint256_optional
  {
    bool exists;
    uint256 value;
  }

  /*
   * Events
   */

  event TournamentCreated(string _discipline, address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentOpened(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentClosed(address _tournamentAddress, uint256 _finalRoundNumber, address _winningSubmissionAddress, uint256 _MTXReward);
  event UserEnteredTournament(address _entrant, address _tournamentAddress);
  event QueryID(string queryID);
  /// @dev Allows tournaments to invoke tournamentOpened events on the platform.
  /// @param _owner Owner of the tournament.
  /// @param _tournamentAddress Address of the tournament.
  /// @param _tournamentName Name of the tournament.
  /// @param _externalAddress External address of the tournament.
  /// @param _MTXReward Reward for winning the tournament.
  /// @param _entryFee Fee for entering into the tournament.
  function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyTournament
  {
    TournamentOpened(_owner, _tournamentAddress, _tournamentName, _externalAddress, _MTXReward, _entryFee);
  }

  /// @dev Allows tournaments to invoke tournamentClosed events on the platform.
  /// @param _tournamentAddress Address of the tournament.
  /// @param _finalRoundNumber Index of the round containing the winning submission.
  /// @param _winningSubmissionAddress Address of the winning submission.
  function invokeTournamentClosedEvent(address _tournamentAddress, uint256 _finalRoundNumber, address _winningSubmissionAddress, uint256 _MTXReward) public onlyTournament
  {
    TournamentClosed(_tournamentAddress, _finalRoundNumber, _winningSubmissionAddress, _MTXReward);
  }

  /* 
   * Modifiers
   */

  modifier onlyTournament
  {
    require(tournamentExists[msg.sender]);
    _;
  }

  modifier onlySubmission
  {
    require(submissionExists[msg.sender]);
    _;
  }

  modifier onlyPeerLinked(address _sender)
  {
    require(hasPeer(_sender));
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
   * State Maintenance Methods
   */

  // @dev Sends out reference requests for a particular submission.
  // @param _references Reference whose authors will be sent requests.
  // @returns Whether or not all references were successfully sent a request.
  function handleReferencesForSubmission(address _submissionAddress, address[] _references) public onlyTournament returns (bool) 
  {
    for(uint256 i = 0; i < _references.length; i++)
    {
      address _referenceAddress = _references[i];

      if(!submissionExists[_referenceAddress])
      {
        // TODO: Introduce uint error codes
        // for returning things like "Reference is not submission"
        return false;
      }

      IMatryxSubmission submission = IMatryxSubmission(_referenceAddress);
      address author = submission.getAuthor();
      address peerAddress = ownerToPeer[author];
      require(peerAddress != 0x0);

      IMatryxPeer peer = IMatryxPeer(peerAddress);

      peer.invokeReferenceRequestEvent(_submissionAddress, _referenceAddress);
      submission.receiveReferenceRequest();
    }
  }

  // @dev Sends out a reference request for a submission (must be called by the submission).
  // @param _reference Reference whose author will be sent a request.
  // @returns Whether or not all references were successfully sent a request.
  function handleReferenceForSubmission(address _reference) public onlySubmission returns (bool)
  {
      require(isSubmission(_reference));
      IMatryxSubmission submission = IMatryxSubmission(_reference);
      address author = submission.getAuthor();
      address peerAddress = ownerToPeer[author];
      require(peerAddress != 0x0);

      IMatryxPeer peer = IMatryxPeer(peerAddress);
      peer.invokeReferenceRequestEvent(msg.sender, _reference);
      submission.receiveReferenceRequest();
  }

  /* 
   * Tournament Entry Methods
   */

  /// @dev Enter the user into a tournament and charge the entry fee.
  /// @param _tournamentAddress Address of the tournament to enter into.
  /// @return _success Whether or not user was successfully entered into the tournament.
  function enterTournament(address _tournamentAddress) public onlyPeerLinked(msg.sender) returns (bool _success)
  {
      // TODO: Consider scheme: 
      // submission owner: peer linked account
      // submission author: peer
      require(tournamentExists[_tournamentAddress]);

      IMatryxTournament tournament = IMatryxTournament(_tournamentAddress);

      bool success = tournament.enterUserInTournament(msg.sender);
      if(success)
      {
        updateUsersTournaments(msg.sender, _tournamentAddress);
        UserEnteredTournament(msg.sender, _tournamentAddress);
      }

      return success;
  }

  /* 
   * Tournament Admin Methods
   */

  /// @dev Create a new tournament.
  /// @param _tournamentName Name of the new tournament.
  /// @param _externalAddress Off-chain content hash of tournament details (ipfs hash)
  /// @param _BountyMTX Total tournament reward in MTX.
  /// @param _entryFee Fee to charge participant upon entering into tournament.
  /// @return _tournamentAddress Address of the newly created tournament
  function createTournament(string _discipline, string _tournamentName, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee, uint256 _reviewPeriod) public onlyPeerLinked(msg.sender) returns (address _tournamentAddress)
  {
    IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
    // Check that the platform has a sufficient allowance to
    // transfer the reward from the tournament creator to itself
    uint256 tournamentsAllowance = matryxToken.allowance(msg.sender, this);
    require(tournamentsAllowance >= _BountyMTX);

    IMatryxTournamentFactory tournamentFactory = IMatryxTournamentFactory(matryxTournamentFactoryAddress);
    address newTournament = tournamentFactory.createTournament(msg.sender, _tournamentName, _externalAddress, _BountyMTX, _entryFee, _reviewPeriod);
    TournamentCreated(_discipline, msg.sender, newTournament, _tournamentName, _externalAddress, _BountyMTX, _entryFee);

    // Transfer the MTX reward to the tournament.
    bool transferSuccess = matryxToken.transferFrom(msg.sender, newTournament, _BountyMTX);
    require(transferSuccess);
    
    // update data structures
    allTournaments.push(newTournament);
    tournamentExists[newTournament] = true;

    return newTournament;
  }

  event successfulTransfer();
  event unsuccessfulTransfer();
  function transferMTXToAddress(address _to, uint256 _amount)
  {
    IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
    bool transferSuccess = matryxToken.transferFrom(msg.sender, _to, _amount);
    if(transferSuccess)
    {
      successfulTransfer();
    }
    else
    {
      unsuccessfulTransfer();
    }
  }

  /*
   * State Maintenance Methods
   */ 

  function updateUsersTournaments(address _author, address _tournament) internal
  {
    entrantToTournamentArray[_author].push(_tournament);
  }

  function updateSubmissions(address _author, address _submission) public onlyTournament
  {
    authorToSubmissionToSubmissionIndex[_author][_submission] = uint256_optional({exists:true, value:authorToSubmissionArray[_author].length});
    authorToSubmissionArray[_author].push(_submission);
    peerToOwnsSubmission[ownerToPeer[_author]][_submission] = true;
    submissionExists[_submission] = true;
  }

  function removeSubmission(address _submissionAddress, address _tournamentAddress) public returns (bool)
  {
    address peerAddress = ownerToPeer[msg.sender];
    require(peerToOwnsSubmission[peerAddress][_submissionAddress]);
    require(tournamentExists[_tournamentAddress]);
    
    if(submissionExists[_submissionAddress])
    {
      IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
      address author = submission.getAuthor();
      uint256 submissionIndex = authorToSubmissionToSubmissionIndex[author][_submissionAddress].value;

      submissionExists[_submissionAddress] = false;
      delete authorToSubmissionArray[author][submissionIndex];
      delete authorToSubmissionToSubmissionIndex[author][_submissionAddress];

      IMatryxTournament(_tournamentAddress).removeSubmission(_submissionAddress, author);
      return true;
    }
    
    return false;
  }

  /*
   * Access Control Methods
   */

  function createPeer() public returns (address)
  {
    require(ownerToPeer[msg.sender] == 0x0);
    IMatryxPeerFactory peerFactory = IMatryxPeerFactory(matryxPeerFactoryAddress);
    address peer = peerFactory.createPeer(msg.sender);
    peerExists[peer] = true;
    ownerToPeer[msg.sender] = peer;
  }

  function isPeer(address _peerAddress) public constant returns (bool)
  {
    return peerExists[_peerAddress];
  }

  function hasPeer(address _sender) public returns (bool)
  {
    return (ownerToPeer[_sender] != 0x0);
  }

  function peerExistsAndOwnsSubmission(address _peer, address _reference) public returns (bool)
  {
    bool isAPeer = peerExists[_peer];
    bool referenceIsSubmission = submissionExists[_reference];
    bool peerOwnsSubmission = peerToOwnsSubmission[_peer][_reference];

    return isAPeer && referenceIsSubmission && peerOwnsSubmission;
  }

  function peerAddress(address _sender) public constant returns (address)
  {
    return ownerToPeer[_sender];
  }

  function isSubmission(address _submissionAddress) public constant returns (bool)
  {
    return submissionExists[_submissionAddress];
  }

  /// @dev Returns whether or not the given tournament belongs to the sender.
  /// @param _tournamentAddress Address of the tournament to check.
  /// @return _isMine Whether or not the tournament belongs to the sender.
  function getTournament_IsMine(address _tournamentAddress) public constant returns (bool _isMine)
  {
    require(tournamentExists[_tournamentAddress]);
    Ownable tournament = Ownable(_tournamentAddress);
    return (tournament.getOwner() == msg.sender);
  }

  /*
   * Getter Methods
   */

   function getTokenAddress() public constant returns (address)
   {
      return matryxTokenAddress;
   }

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
}