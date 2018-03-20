pragma solidity ^0.4.18;

import '../libraries/strings/strings.sol';
import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/factories/IMatryxRoundFactory.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxToken.sol';
import './Ownable.sol';

/// @title Tournament - The Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxTournament is Ownable, IMatryxTournament {
    using SafeMath for uint256;
    using strings for *;
    
    // TODO: condense and put in structs
    //Platform identification
    address public platformAddress;
    address public matryxTokenAddress;
    address public matryxRoundFactoryAddress;

    //Tournament identification
    string public title;
    bytes32 public externalAddress;
    string public discipline;

    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    mapping(address=>bool) public isRound;
    uint256 public reviewPeriod;
    uint256 public tournamentClosedTime;
    uint public maxRounds = 3;
    bool public tournamentOpen = false;

    // Reward and fee
    uint256 public BountyMTX;
    uint256 public BountyMTXLeft;
    uint256 public entryFee;

    // TODO: Automatic round creation mechanism

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address=>address[]) private entrantToSubmissions;
    mapping(address=>mapping(address=>uint256_optional)) private entrantToSubmissionToSubmissionIndex;
    mapping(address=>bool) private addressToIsEntrant;
    address[] private allEntrants;

    function MatryxTournament(address _platformAddress, address _matryxTokenAddress, address _matryxRoundFactoryAddress, address _owner, string _tournamentTitle, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee, uint256 _reviewPeriod) public {
        //Clean inputs
        require(_owner != 0x0);
        //require(!_tournamentName.toSlice().empty());
        require(_BountyMTX > 0);
        require(_matryxRoundFactoryAddress != 0x0);
        
        platformAddress = _platformAddress;
        matryxTokenAddress = _matryxTokenAddress;
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;

        timeCreated = now;
        // Identification
        owner = _owner;
        title = _tournamentTitle;
        externalAddress = _externalAddress;
        // Reward and fee
        BountyMTX = _BountyMTX;
        BountyMTXLeft = _BountyMTX;
        entryFee = _entryFee;
        reviewPeriod = _reviewPeriod;
    }

    /*
     * Structs
     */

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    struct SubmissionLocation
    {
        uint256 roundIndex;
        uint256 submissionIndex;
    }

    /*
     * Events
     */

    event RoundStarted(uint256 _roundIndex);
    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, address _submissionAddress);
    event RoundWinnerChosen(address _submissionAddress);

    /// @dev Allows rounds to invoke SubmissionCreated events on this tournament.
    /// @param _submissionAddress Address of the submission.
    function invokeSubmissionCreatedEvent(address _submissionAddress) public
    {
        SubmissionCreated(rounds.length-1, _submissionAddress);
    }

    /*
     * Modifiers
     */

    /// @dev Requires the function caller to be the platform.
    modifier onlyPlatform()
    {
        require(msg.sender == platformAddress);
        _;
    }

    modifier onlyRound()
    {
        require(isRound[msg.sender]);
        _;
    }

    modifier onlySubmission(address _submissionAddress, address _author)
    {
        // If the submission does not exist,
        // the address of the submission we return will not be msg.sender
        // It will either be 
        // 1) The first submission, or
        // 2) all 0s from having deleted it previously.
        uint256 indexOfSubmission = entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].value;
        address submissionAddress = entrantToSubmissions[_author][indexOfSubmission];
        require(_submissionAddress == msg.sender);
        _;
    }

    modifier onlyPeerLinked(address _sender)
    {
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        require(platform.hasPeer(_sender));
        _;
    }

    /// @dev Requires the function caller to be an entrant.
    modifier onlyEntrant()
    {
        bool senderIsEntrant = addressToIsEntrant[msg.sender];
        require(senderIsEntrant);
        _;
    }

    /// @dev Requires the function caller to be the platform or the owner of this tournament
    modifier platformOrOwner()
    {
        require((msg.sender == platformAddress)||(msg.sender == owner));
        _;
    }

    modifier whileTournamentOpen()
    {
        require(isOpen());
        _;
    }

    /// @dev Requires the tournament to be open.
    modifier duringReviewPeriod()
    {
        // TODO: Finish me!
        require(isInReview());
        _;
    }

    modifier whileRoundsLeft()
    {
        require(rounds.length < maxRounds);
        _;
    }

    modifier whileBountyLeft(uint256 _nextRoundBounty)
    {
        require(BountyMTXLeft.sub(_nextRoundBounty) >= 0);
        _;
    }

    /*
    * State Maintenance Methods
    */

    function removeSubmission(address _submissionAddress, address _author) public onlyPlatform returns (bool)
    {
        if(entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].exists)
        {
            numberOfSubmissions = numberOfSubmissions.sub(1);
            delete entrantToSubmissions[_author][entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].value];
            delete entrantToSubmissionToSubmissionIndex[_author][_submissionAddress];
            return true;
        }

        return false;
    }

    /*
     * Access Control Methods
     */

    /// @dev Returns whether or not the sender is an entrant in this tournament
    /// @param _sender Explicit sender address.
    /// @return Whether or not the sender is an entrant in this tournament.
    function isEntrant(address _sender) public view returns (bool)
    {
        return addressToIsEntrant[_sender];
    }

    /// @dev Returns true if the tournament is open.
    /// @return Whether or not the tournament is open.
    function isOpen() public view returns (bool)
    {
        return tournamentOpen;
    }

    function isInReview() public view returns (bool)
    {
        bool tournamentEndedBeforeNow = now >= tournamentClosedTime;
        bool tournamentReviewNotOver = now <= tournamentClosedTime + reviewPeriod;
        bool inReview = tournamentEndedBeforeNow && tournamentReviewNotOver;
        return inReview;
    }

    /// @dev Returns whether or not a round of this tournament is open.
    /// @return _roundOpen Whether or not a round is open on this tournament.
    function roundIsOpen() public constant returns (bool)
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        return round.isOpen();
    }

    /*
     * Getter Methods
     */

     function getPlatform() public view returns (address _platformAddress)
     {
        return platformAddress;
     }

    /// @dev Returns the external address of the tournament.
    /// @return _externalAddress Off-chain content hash of tournament details (ipfs hash)
    function getExternalAddress() public view returns (bytes32 _externalAddress)
    {
        return externalAddress;
    }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound() public constant returns (uint256 _currentRound, address _currentRoundAddress)
    {
        return (rounds.length, rounds[rounds.length-1]);
    }

    /// @dev Returns all of the sender's submissions to this tournament.
    /// @return (_roundIndices[], _submissionIndices[]) Locations of the sender's submissions.
    function mySubmissions() public view returns (address[])
    {
        address[] memory _mySubmissions = entrantToSubmissions[msg.sender];
        return _mySubmissions;
    }

    /// @dev Returns the number of submissions made to this tournament.
    /// @return _submissionCount Number of submissions made to this tournament.
    function submissionCount() public view returns (uint256 _submissionCount)
    {
        return numberOfSubmissions;
    }

    function entrantCount() public view returns (uint256 _entrantCount)
    {
        return allEntrants.length;
    }

    /*
     * Setter Methods
     */

    function setTitle(string _title) public onlyOwner
    {
        title = _title;
    }

    function setExternalAddress(bytes32 _externalAddress) public onlyOwner
    {
        externalAddress = _externalAddress;
    }

    function setEntryFee(uint256 _entryFee) public onlyOwner
    {
        entryFee = _entryFee;
    }

    /// @dev Set the maximum number of rounds for the tournament.
    /// @param _newMaxRounds New maximum number of rounds possible for this tournament.
    function setNumberOfRounds(uint256 _newMaxRounds) public platformOrOwner
    {
        maxRounds = _newMaxRounds;
    }

    function setDiscipline(string _discipline) public onlyOwner
    {
        discipline = _discipline;
    }

    /*
     * Tournament Admin Methods
     */

    /// @dev Opens this tournament up to submissions; called by startRound.
    function openTournament() internal platformOrOwner
    {
        tournamentOpen = true;
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.invokeTournamentOpenedEvent(owner, this, title, externalAddress, BountyMTX, entryFee);
    }

    /// @dev Chooses the winner for the round. If this is the last round, closes the tournament.
    /// @param _submissionAddress Address of the winning submission
    function chooseWinner(address _submissionAddress) public platformOrOwner
    {
        // TODO: Implement popular vote default winner chosen to avoid
        // locking up MTX in this tournament (would happen if the tournament
        // poser tried to choose a winner after the review period ended).
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.chooseWinningSubmission(_submissionAddress);
        RoundWinnerChosen(_submissionAddress);

        if(rounds.length == maxRounds)
        {
            require(isInReview());
            tournamentOpen = false;

            IMatryxPlatform platform = IMatryxPlatform(platformAddress);
            platform.invokeTournamentClosedEvent(this, rounds.length, _submissionAddress, round.getBounty());

            for(uint256 i = 0; i < allEntrants.length; i++)
            {
                IMatryxToken(matryxTokenAddress).transfer(allEntrants[i], entryFee);
            }
        }
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(uint256 _bountyMTX) public onlyOwner whileRoundsLeft whileBountyLeft(_bountyMTX) returns (address _roundAddress) 
    {
        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        address newRoundAddress;

        if(rounds.length+1 == maxRounds)
        {
            uint256 lastBounty = BountyMTXLeft;
            newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, BountyMTXLeft);
            BountyMTXLeft = 0;
            // Transfer the round bounty to the round.
            matryxToken.transfer(newRoundAddress, lastBounty);
        }
        else
        {
            uint256 remainingBountyAfterRoundCreated = BountyMTXLeft.sub(_bountyMTX);
            newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, _bountyMTX);
            BountyMTXLeft = remainingBountyAfterRoundCreated;
            // Transfer the round bounty to the round.
            matryxToken.transfer(newRoundAddress, _bountyMTX);
        }
        
        isRound[newRoundAddress] = true;
        rounds.push(newRoundAddress);
        return newRoundAddress;
    }

    /// @dev Starts the latest round.
    /// @param _duration Duration of the round in seconds.
    function startRound(uint256 _duration, uint256 _reviewPeriod) public
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.Start(_duration, _reviewPeriod);
        if(!tournamentOpen)
        {
            openTournament();
        }

        if(rounds.length == maxRounds)
        {
            tournamentClosedTime = now + _duration;
        }

        RoundStarted(rounds.length-1);
    }

    /*
     * Entrant Methods
     */

    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(address _entrantAddress) public onlyPlatform whileTournamentOpen returns (bool success)
    {
        if(addressToIsEntrant[_entrantAddress] == true)
        {
            return false;
        }

        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        // Check that this tournament has a sufficient allowance to
        // transfer the entry fee from the entrant to itself
        uint256 tournamentsAllowance = matryxToken.allowance(_entrantAddress, this);
        require(tournamentsAllowance >= entryFee);

        // Make the MTX transfer.
        bool transferSuccess = matryxToken.transferFrom(_entrantAddress, this, entryFee);
        require(transferSuccess);

        // Finally, change the tournament's state to reflect the user entering.
        addressToIsEntrant[_entrantAddress] = true;
        allEntrants.push(_entrantAddress);
        return true;
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return entryFee;
    }

    function createSubmission(string _title, address _owner, bytes32 _externalAddress, address[] _contributors, address[] _references, bool _publicallyAccessible) public onlyEntrant onlyPeerLinked(msg.sender) whileTournamentOpen returns (address _submissionAddress)
    {
        // This check is critical for MatryxPeer.
        address peerAddress = IMatryxPlatform(platformAddress).peerAddress(_owner);
        require(peerAddress != 0x0);

        address submissionAddress = IMatryxRound(rounds[rounds.length-1]).createSubmission(_title, _owner, peerAddress, _externalAddress, _references, _contributors, _publicallyAccessible);
        // Send out reference requests to the authors of other submissions
        IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(submissionAddress, _references);

        numberOfSubmissions = numberOfSubmissions.add(1);
        entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress] = uint256_optional({exists:true, value:entrantToSubmissions[msg.sender].length});
        entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform(platformAddress).updateSubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }
}