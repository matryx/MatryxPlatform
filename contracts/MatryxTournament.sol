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
    string name;
    bytes32 public externalAddress;

    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    uint256 public reviewPeriod;
    uint256 public tournamentClosedTime;
    uint public maxRounds = 1;
    bool public tournamentOpen = false;

    // Reward and fee
    uint public BountyMTX;
    uint256 public entryFee;

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address => SubmissionLocation[]) private giveEntrantAddressGetSubmissions;
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
    event SubmissionCreated(uint256 _roundIndex, uint256 _submissionIndex);
    event RoundWinnerChosen(uint256 _submissionIndex);

    event CurrentRound(uint256 _roundIndex);

    /// @dev Allows rounds to invoke SubmissionCreated events on this tournament.
    /// @param _submissionIndex Index of the submission.
    function invokeSubmissionCreatedEvent(uint256 _submissionIndex) public
    {
        SubmissionCreated(rounds.length-1, _submissionIndex);
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

    modifier whileRoundAcceptingSubmissions()
    {
        require(rounds.length > 0);
        IMatryxRound currentRound = IMatryxRound(rounds[rounds.length-1]);
        require(currentRound.isOpen());
        _;
    }

    /*
     * Setter Methods
     */

     // TODO: Implement setters.

    /*
     * Access Control Methods
     */

    /// @dev Returns whether or not the sender is the creator of this tournament.
    /// @param _sender Explicit sender address.
    /// @return Whether or not the sender is the creator.
    function isCreator(address _sender) public view returns (bool)
    {
        bool senderIsOwner = _sender == owner;
        return senderIsOwner;
    }

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
    function currentRound() public constant returns (uint256 _currentRound)
    {
        return rounds.length;
    }

    /// @dev Returns all of the sender's submissions to this tournament.
    /// @return (_roundIndices[], _submissionIndices[]) Locations of the sender's submissions.
    function mySubmissions() public view returns (uint256[] _roundIndices, uint256[] _submissionIndices)
    {
        SubmissionLocation[] memory submissionLocations = giveEntrantAddressGetSubmissions[msg.sender];
        uint256[] memory roundIndices;
        uint256[] memory submissionIndices;
        for(uint256 i = 0; i < submissionLocations.length; i++)
        {
            roundIndices[i] = submissionLocations[i].roundIndex;
            submissionIndices[i] = submissionLocations[i].submissionIndex;
        }

        return (roundIndices, submissionIndices);
    }

    /// @dev Returns all of the sender's submissions to this tournament
    /// @param _sender Explicit sender address.
    /// @return (_roundIndices[], _submissionIndices[]) Locations of the sender's submissions.
    function submissionsByAddress(address _sender) public view onlyPlatform returns (uint256[] _roundIndices, uint256[] _submissionIndices)
    {
        SubmissionLocation[] memory submissionLocations = giveEntrantAddressGetSubmissions[_sender];
        uint256[] memory roundIndices;
        uint256[] memory submissionIndices;
        for(uint256 i = 0; i < submissionLocations.length; i++)
        {
            roundIndices[i] = submissionLocations[i].roundIndex;
            submissionIndices[i] = submissionLocations[i].submissionIndex;
        }
        
        return (roundIndices, submissionIndices);
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
        
        // Implement me!
        tournamentOpen = true;

        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        platform.invokeTournamentOpenedEvent(owner, this, name, externalAddress, BountyMTX, entryFee);
    }

    /// @dev Chooses the winner for the round.
    /// @param _submissionIndex Index of the winning submission
    function chooseWinner(uint256 _submissionIndex) public platformOrOwner
    {
        // require(_submissionIndex > (rounds.length-1));
        tournamentOpen = false;
        
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        round.chooseWinningSubmission(_submissionIndex);
        //address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
        //IMatryxToken.approve(winningAuthor, round.bountyMTX);

        RoundWinnerChosen(_submissionIndex);

        //TODO: Add logic to check if is the last round.
        //If so, invoke an event on the platform signaling
        //that the tournament has closed.
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(uint256 _bountyMTX) public returns (address _roundAddress)
    {
        BountyMTX = BountyMTX.sub(_bountyMTX);

        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress = roundFactory.createRound(this, _bountyMTX);

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
    function closeTournament(uint256 _submissionIndex) public onlyPlatform
    {
        require(_submissionIndex < numberOfSubmissions);

        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);

        address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
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

    function createSubmission(string _name, address _author, bytes32 _externalAddress, address[] _contributors, address[] _references, bool _publicallyAccessible) public returns (uint256 _submissionIndex)
    {
        CurrentRound(rounds.length-1);
        IMatryxRound round = IMatryxRound(rounds[rounds.length-1]);
        uint256 submissionIndex = round.createSubmission(_name, _author, _externalAddress, _references, _contributors, _publicallyAccessible);
        numberOfSubmissions += 1;
        return submissionIndex;
    }
}