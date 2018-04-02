pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../libraries/math/SafeMath128.sol';
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
  using SafeMath for uint256;
  using SafeMath128 for uint128;

  // TODO: condense and put in structs
  address public matryxTokenAddress;
  address matryxPeerFactoryAddress;
  address matryxTournamentFactoryAddress;
  address matryxSubmissionTrustLibAddress;
  address matryxRoundLibAddress;

  address[] public allTournaments;
  bytes32 public hashOfTopCategory;
  bytes32 public hashOfLastCategory;
  mapping(uint256=>bytes32) public topCategoryByCount;
  mapping(bytes32=>category) public categoryIterator;
  string[] public categoryList;

  mapping(address=>bool) peerExists;
  mapping(address=>address) ownerToPeerAndPeerToOwner;
  mapping(address=>mapping(address=>bool)) addressToOwnsSubmission;
  mapping(address=>bool) tournamentExists;
  mapping(address=>bool) submissionExists;

  mapping(address=>address[]) entrantToTournamentArray;
  mapping(address=>address[]) ownerToSubmissionArray;
  mapping(address=>mapping(address=>uint256_optional))  ownerToSubmissionToSubmissionIndex;

  uint256_optional submissionGratitude = uint256_optional({exists: true, value: 2*10**17});

  function MatryxPlatform(address _matryxTokenAddress, address _matryxPeerFactoryAddress, address _matryxTournamentFactoryAddress, address _matryxSubmissionTrustLibAddress) public
  {
    matryxTokenAddress = _matryxTokenAddress;
    matryxPeerFactoryAddress = _matryxPeerFactoryAddress;
    matryxTournamentFactoryAddress = _matryxTournamentFactoryAddress;
    matryxSubmissionTrustLibAddress = _matryxSubmissionTrustLibAddress;
  }

  /*
   * Structs
   */

  struct uint256_optional
  {
    bool exists;
    uint256 value;
  }

  struct category
  {
    string name;
    uint128 count;
    bytes32 prev;
    bytes32 next;
    address[] tournaments;
  }

  /*
   * Events
   */

  event TournamentCreated(string _discipline, address _owner, address _tournamentAddress, string _tournamentName, bytes _externalAddress, uint256 _MTXReward, uint256 _entryFee);
  event TournamentOpened(address _owner, address _tournamentAddress, string _tournamentName, bytes _externalAddress, uint256 _MTXReward, uint256 _entryFee);
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
  function invokeTournamentOpenedEvent(address _owner, address _tournamentAddress, string _tournamentName, bytes _externalAddress, uint256 _MTXReward, uint256 _entryFee) public onlyTournament
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
  function handleReferenceRequestsForSubmission(address _submissionAddress, address[] _references) public onlyTournament returns (bool) 
  {
    for(uint256 i = 0; i < _references.length; i++)
    {
      address _referenceAddress = _references[i];

      if(!isSubmission(_referenceAddress))
      {
        // TODO: Introduce uint error codes
        // for returning things like "Reference _ is not submission"
        continue;
      }

      IMatryxSubmission submission = IMatryxSubmission(_referenceAddress);
      address author = submission.getAuthor();
      IMatryxPeer(author).receiveReferenceRequest(_submissionAddress, _referenceAddress);
      submission.receiveReferenceRequest();
    }
  }

  // @dev Sends out a reference request for a submission (must be called by the submission).
  // @param _reference Reference whose author will be sent a request.
  // @returns Whether or not all references were successfully sent a request.
  function handleReferenceRequestForSubmission(address _reference) public onlySubmission returns (bool)
  {
      require(isSubmission(_reference));
      IMatryxSubmission submission = IMatryxSubmission(_reference);
      address author = submission.getAuthor();
      IMatryxPeer(author).receiveReferenceRequest(msg.sender, _reference);
      submission.receiveReferenceRequest();
  }

  function handleCancelledReferenceRequestForSubmission(address _reference) public onlySubmission returns (bool)
  {
    require(isSubmission(_reference));
    IMatryxSubmission submission = IMatryxSubmission(_reference);
    address author = submission.getAuthor();
    IMatryxPeer(author).receiveCancelledReferenceRequest(msg.sender, _reference);
    submission.cancelReferenceRequest();
  }

  function updateUsersTournaments(address _owner, address _tournament) internal
  {
    entrantToTournamentArray[_owner].push(_tournament);
  }

  function updateSubmissions(address _owner, address _submission) public onlyTournament
  {
    ownerToSubmissionToSubmissionIndex[_owner][_submission] = uint256_optional({exists:true, value:ownerToSubmissionArray[_owner].length});
    ownerToSubmissionArray[_owner].push(_submission);
    addressToOwnsSubmission[_owner][_submission] = true;
    submissionExists[_submission] = true;
  }

  function removeSubmission(address _submissionAddress, address _tournamentAddress) public returns (bool)
  {
    require(addressToOwnsSubmission[msg.sender][_submissionAddress]);
    require(tournamentExists[_tournamentAddress]);
    
    if(submissionExists[_submissionAddress])
    {
      IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
      address owner = Ownable(_submissionAddress).getOwner();
      uint256 submissionIndex = ownerToSubmissionToSubmissionIndex[owner][_submissionAddress].value;

      submissionExists[_submissionAddress] = false;
      delete ownerToSubmissionArray[owner][submissionIndex];
      delete ownerToSubmissionToSubmissionIndex[owner][_submissionAddress];

      IMatryxTournament(_tournamentAddress).removeSubmission(_submissionAddress, owner);
      return true;
    }
    
    return false;
  }

  function addTournamentToCategory(address _tournamentAddress, string _category) internal
  {
    bytes32 hashOfCategory = keccak256(_category);
    // If this is the first tournament in its category
    if(categoryIterator[hashOfCategory].count == 0)
    {
      // Push the new category to a list of categories
      categoryList.push(_category);

      // If its the first category ever
      if(hashOfTopCategory == 0x0)
      {
        // Update the top category pointer
        hashOfTopCategory = hashOfCategory;
        hashOfLastCategory = hashOfCategory;
        // Create a new entry in the iterator for it and don't store previous or next pointers
        categoryIterator[hashOfCategory] = category({name: _category, count: 1, prev: 0, next: 0, tournaments: new address[](0)});
        // Store the mapping from count 1 to this category
        topCategoryByCount[1] = hashOfCategory;
      }
      else
      {
        // If this is not the first category ever,
        // Create a new iterator entry, complete with a prev pointer to the previous last category
        categoryIterator[hashOfCategory] = category({name: _category, count: 1, prev: hashOfLastCategory, next: 0x0, tournaments: new address[](0)});
        // Update that previous last category's next pointer (there's one more after it now)
        categoryIterator[hashOfLastCategory].next = hashOfCategory;

        if(topCategoryByCount[1] == 0x0)
        {
          topCategoryByCount[1] = hashOfCategory;
        }
      }

      // Push to the tournaments list for this category
      categoryIterator[hashOfCategory].tournaments.push(_tournamentAddress);
      // Update the last category pointer
      hashOfLastCategory = hashOfCategory;
      return;
    }

    categoryIterator[hashOfCategory].tournaments.push(_tournamentAddress);

    uint256 categoryCount = categoryIterator[hashOfCategory].count;
    // If this category has the top relative count (category.prev.count > category.count):
    //  If category.next exists, the top category for our previous count becomes category.next,
    //  otherwise (category.next doesn't exist), the top category for our previous count
    //  we set to 0x0.
    if(topCategoryByCount[categoryIterator[hashOfCategory].count] == hashOfCategory)
    {
      if(categoryIterator[hashOfCategory].next != 0x0)
      {
        topCategoryByCount[categoryCount] = categoryIterator[hashOfCategory].next;
      }
      else
      {
        topCategoryByCount[categoryCount] = 0x0;
      }
    }

    uint128 newCount = categoryIterator[hashOfCategory].count + 1;
    categoryIterator[hashOfCategory].count = newCount;

    // If the top category for our new count is not defined, 
    // define it as this category.
    if(topCategoryByCount[newCount] == 0)
    {
      topCategoryByCount[newCount] = hashOfCategory;
    }

    // If the count of the category is now greater than the previous category
    // swap it with the top category of its count.
    if(categoryIterator[hashOfCategory].prev != 0x0)
    {
      if(categoryIterator[hashOfCategory].count > categoryIterator[categoryIterator[hashOfCategory].prev].count)
      {
        // define A as the top category of its count
        bytes32 hashOfTopA = topCategoryByCount[categoryIterator[hashOfCategory].count-1];
        if(hashOfTopA == hashOfTopCategory)
        {
          hashOfTopCategory = hashOfCategory;
        }

        if(hashOfCategory == hashOfLastCategory)
        {
          hashOfLastCategory = categoryIterator[hashOfCategory].prev;
        }

        category storage A = categoryIterator[hashOfTopA];
        category storage B = categoryIterator[hashOfCategory];

        bool adjacent = A.next == hashOfCategory;
        bytes32 Bprev = B.prev;
        bytes32 Anext = A.next;

        A.next = B.next;
        B.prev = A.prev;

        if(A.prev != 0x0)
        {
          categoryIterator[A.prev].next = hashOfCategory;
        }
        if(B.next != 0x0)
        {
          categoryIterator[B.next].prev = hashOfTopA;
        }
        
        if(adjacent)
        {
          A.prev = hashOfCategory;
          B.next = hashOfTopA;
        }
        else
        {
          A.prev = Bprev;
          B.next = Anext;
          if(Bprev != 0x0)
          {
            categoryIterator[Bprev].next = hashOfTopA;
          }
          if(Anext != 0x0)
          {
            categoryIterator[Anext].prev = hashOfCategory;
          }
        }
      }
    }
  }

  function getTournamentsByCategory(string _category) external constant returns (address[])
  {
    return categoryIterator[keccak256(_category)].tournaments;
  }

  function getCategoryCount(string _category) external constant returns (uint256)
  {
    return categoryIterator[keccak256(_category)].count;
  }

  function getTopCategory(uint256 _index) external constant returns (string)
  {
    bytes32 categoryHash = hashOfTopCategory;
    string storage categoryName  = categoryIterator[categoryHash].name;

    for(uint256 i = 1; i <= _index; i++)
    {
      categoryHash = categoryIterator[categoryHash].next;
      categoryName = categoryIterator[categoryHash].name;
    
      if(categoryHash == 0x0)
      {
        break;
      }
    }

    return categoryName;
  }

  function switchTournamentCategory(string discipline) onlyTournament public
  {
    revert();
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
  function createTournament(string _category, string _tournamentName, bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public onlyPeerLinked(msg.sender) returns (address _tournamentAddress)
  {
    IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
    // Check that the platform has a sufficient allowance to
    // transfer the reward from the tournament creator to itself
    require(matryxToken.allowance(msg.sender, this) >= _BountyMTX);

    IMatryxTournamentFactory tournamentFactory = IMatryxTournamentFactory(matryxTournamentFactoryAddress);
    address newTournament = tournamentFactory.createTournament(msg.sender, _category, _tournamentName, _externalAddress, _BountyMTX, _entryFee);
    TournamentCreated(_category, msg.sender, newTournament, _tournamentName, _externalAddress, _BountyMTX, _entryFee);
    
    addTournamentToCategory(newTournament, _category);

    // Transfer the MTX reward to the tournament.
    bool transferSuccess = matryxToken.transferFrom(msg.sender, newTournament, _BountyMTX);
    require(transferSuccess);
    
    // update data structures
    allTournaments.push(newTournament);
    tournamentExists[newTournament] = true;

    return newTournament;
  }

  /*
   * Access Control Methods
   */

  function createPeer() public returns (address)
  {
    require(ownerToPeerAndPeerToOwner[msg.sender] == 0x0);
    IMatryxPeerFactory peerFactory = IMatryxPeerFactory(matryxPeerFactoryAddress);
    address peer = peerFactory.createPeer(msg.sender);
    peerExists[peer] = true;
    ownerToPeerAndPeerToOwner[msg.sender] = peer;
    ownerToPeerAndPeerToOwner[peer] = msg.sender;
  }

  function isPeer(address _peerAddress) public constant returns (bool)
  {
    return peerExists[_peerAddress];
  }

  // TODO: add constant
  function hasPeer(address _sender) public constant returns (bool)
  {
    return (ownerToPeerAndPeerToOwner[_sender] != 0x0);
  }

  // TODO: add constant
  function peerExistsAndOwnsSubmission(address _peer, address _reference) public constant returns (bool)
  {
    bool isAPeer = peerExists[_peer];
    bool referenceIsSubmission = submissionExists[_reference];
    bool peerOwnsSubmission = addressToOwnsSubmission[ownerToPeerAndPeerToOwner[_peer]][_reference];

    return isAPeer && referenceIsSubmission && peerOwnsSubmission;
  }

  function peerAddress(address _sender) public constant returns (address)
  {
    return ownerToPeerAndPeerToOwner[_sender];
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
   * Setter Methods
   */ 

    /// @dev              Set the relative amount of MTX to be delivered to a submission's
    ///                   references
    /// @param _gratitude Weight from 0 to 1 (18 decimal uint) specifying enforced submission 
    ///                   gratitude
    function setSubmissionGratitude(uint256 _gratitude) public onlyOwner
    {
        assert(_gratitude >= 0 && _gratitude <= (1*10**18));
        submissionGratitude = uint256_optional({exists: true, value: _gratitude});
    }

  /*
   * Getter Methods
   */

   function getTokenAddress() public constant returns (address)
   {
      return matryxTokenAddress;
   }

   function getSubmissionTrustLibrary() public constant returns (address)
   {
      return matryxSubmissionTrustLibAddress;
   }

   function getRoundLibAddress() public constant returns (address)
   {
      return matryxRoundLibAddress;
   }

   /// @dev    Returns a weight from 0 to 1 (18 decimal uint) indicating
   ///         how much of a submission's reward goes to its references.
   /// @return Relative amount of MTX going to references of submissions under this tournament.
   function getSubmissionGratitude() public constant returns (uint256)
   {
      require(submissionGratitude.exists);
      return submissionGratitude.value;
   }

   /// @dev Returns addresses for submissions the sender has created.
   /// @return Address array representing submissions.
   function myTournaments() public constant returns (address[])
   {
      return entrantToTournamentArray[msg.sender];
   }

   function mySubmissions() public constant returns (address[])
   {
    return ownerToSubmissionArray[msg.sender];
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