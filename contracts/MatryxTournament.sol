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

    //Platform identification
    address public platformAddress;
    address public matryxRoundFactoryAddress;
    address public matryxTokenAddress;

    //Tournament identification
    string public name;
    bytes32 public externalAddress;

    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    uint256 public reviewPeriod;
    uint256 public tournamentClosedTime;
    uint public maxRounds = 3;
    bool public tournamentOpen = false;

    // Reward and fee
    uint public BountyMTX;
    uint256 public entryFee;

    // TODO: Automatic round creation variable

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address => address[]) private entrantToSubmissions;
    mapping(address => bool) private addressToIsEntrant;

    function MatryxTournament(address _platformAddress, address _matryxRoundFactoryAddress, address _owner, string _tournamentName, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public {
        //Clean inputs
        require(_owner != 0x0);
        require(!_tournamentName.toSlice().empty());
        require(_BountyMTX > 0);
        require(_matryxRoundFactoryAddress != 0x0);
        
        platformAddress = _platformAddress;
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;

        timeCreated = now;
        // Identification
        owner = _owner;
        name = _tournamentName;
        externalAddress = _externalAddress;
        // Reward and fee
        BountyMTX = _BountyMTX;
        entryFee = _entryFee;
    }

    /*
     * Structs
     */

    struct SubmissionLocation
    {
        uint256 roundIndex;
        uint256 submissionIndex;
    }

    /*
     * Events
     */

    event RoundCreated(uint256 _roundIndex);
    event RoundStarted(uint256 _roundIndex);
    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, address _submissionAddress);
    event RoundWinnerChosen(uint256 _submissionIndex);

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

    /// @dev Requires the tournament to be open.
    modifier whileTournamentOpen()
    {
        // TODO: Finish me!
        require(tournamentOpen);
        _;
    }

    modifier whileRoundsLeft()
    {
        require(rounds.length < maxRounds);
        _;
    }

    /*
     * Setter Methods
     */

     // TODO: Implement setters.

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
    function tournamentOpen() public view returns (bool)
    {
        return tournamentOpen;
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

    /*
     * Tournament Admin Methods
     */

    /// @dev Opens this tournament up to submissions.
    function openTournament() public platformOrOwner
    {
        // TODO: Uncomment.
        //uint allowedMTX = IMatryxToken(matryxTokenAddress).allowance(msg.sender, this);
        //require(allowedMTX >= BountyMTX);
        //require(IMatryxToken(matryxTokenAddress).transferFrom(msg.sender, this, BountyMTX));
        
        tournamentOpen = true;

        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.invokeTournamentOpenedEvent(owner, this, name, externalAddress, BountyMTX, entryFee);
    }

    /// @dev Chooses the winner for the round. If this is the last round, closes the tournament.
    /// @param _submissionIndex Index of the winning submission
    function chooseWinner(uint256 _submissionIndex) public platformOrOwner whileTournamentOpen
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        //address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
        round.chooseWinningSubmission(_submissionIndex);
        //IMatryxToken.approve(winningAuthor, round.bountyMTX);
        RoundWinnerChosen(_submissionIndex);

        if(rounds.length == maxRounds)
        {
            tournamentOpen = false;
            IMatryxPlatform platform = IMatryxPlatform(platformAddress);
            platform.invokeTournamentClosedEvent(this, rounds.length, _submissionIndex);
        }
    }

    /// @dev Set the maximum number of rounds for the tournament.
    /// @param _newMaxRounds New maximum number of rounds possible for this tournament.
    function setNumberOfRounds(uint256 _newMaxRounds) public platformOrOwner
    {
        maxRounds = _newMaxRounds;
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(uint256 _bountyMTX) public whileRoundsLeft returns (address _roundAddress) 
    {
        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress;

        if(rounds.length+1 == maxRounds)
        {
            uint256 _BountyMTX = BountyMTX;
            BountyMTX = 0;
            newRoundAddress = roundFactory.createRound(this, msg.sender, _BountyMTX);
        }
        else
        {
            BountyMTX = BountyMTX.sub(_bountyMTX);
            newRoundAddress = roundFactory.createRound(this, msg.sender, _bountyMTX);
        }
        
        rounds.push(newRoundAddress);
        return address(newRoundAddress);
    }

    /// @dev Starts the latest round.
    /// @param _duration Duration of the round in seconds.
    function startRound(uint256 _duration) public 
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.Start(_duration);
        RoundStarted(rounds.length-1);
    }

    // @dev Closes the tournament.
    // @param _submissionIndex Index of the winning submission.
    function closeTournament(uint256 _submissionIndex) public onlyOwner
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        if(!round.submissionChosen())
        {
            round.chooseWinningSubmission(_submissionIndex);
            RoundWinnerChosen(_submissionIndex);
        }
        else
        {
            round.awardBounty(_submissionIndex, BountyMTX);
        }

        //address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
        //IMatryxToken.approve(winningAuthor, BountyMTX);

        tournamentOpen = false;

        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.invokeTournamentClosedEvent(this, rounds.length, _submissionIndex);
    }

    /*
     * Entrant Methods
     */

    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(address _entrantAddress) public onlyPlatform returns (bool success)
    {
        if(addressToIsEntrant[_entrantAddress] == true)
        {
            return false;
        }

        addressToIsEntrant[_entrantAddress] = true;
        return true;
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return entryFee;
    }

    function createSubmission(string _name, address _author, bytes32 _externalAddress, address[] _contributors, address[] _references, bool _publicallyAccessible) public onlyEntrant whileTournamentOpen returns (address _submissionAddress)
    {
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        address submissionAddress = round.createSubmission(_name, _author, _externalAddress, _references, _contributors, _publicallyAccessible);

        numberOfSubmissions += 1;
        entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.updateMySubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }
}