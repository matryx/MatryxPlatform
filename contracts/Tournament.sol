pragma solidity ^0.4.18;

import './Ownable.sol';
import './MatryxPlatform.sol';
import './Round.sol';
import './MatryxToken.sol';

/// @title Tournament - The Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract Tournament is Ownable {
    using SafeMath for uint256;

    //Platform identification
    address public platformAddress;
    address public matryxTokenAddress;

    //Tournament identification
    string name;
    address public owner;
    bytes32 public externalAddress;

    // Timing
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    Round[] public rounds;
    uint256 public reviewPeriod;
    uint256 public tournamentClosedTime;
    uint public maxRounds = 1;
    bool public tournamentOpen = true;

    // Reward and fee
    uint public BountyMTX;
    uint256 public entryFee;

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address => SubmissionLocation[]) private giveEntrantAddressGetSubmissions;
    mapping(address => bool) private addressToIsEntrant;

    function Tournament(address _owner, string _tournamentName, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public {
        //Clean inputs
        require(_owner != 0x0);
        require(!stringIsEmpty(_tournamentName));
        require(_BountyMTX > 0);
        
        platformAddress = msg.sender;
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

    /// @dev Allows rounds to invoke SubmissionCreated events on this tournament.
    /// @param _roundIndex Index of the round the submission was made to.
    /// @param _submissionIndex Index of the submission.
    function invokeSubmissionCreatedEvent(uint256 _roundIndex, uint256 _submissionIndex) public
    {
        SubmissionCreated(_roundIndex, _submissionIndex);
    }

    /*
     * Modifiers
     */

    /// @dev Requires the function caller to be the platform.
    modifier onlyPlatform()
    {
        require(platformAddress == msg.sender);
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

    /// @dev Requires the round to be open
    modifier whileRoundOpen()
    {
        // TODO: Implement me!
        require(rounds[rounds.length-1].roundIsOpen());
        _;
    }

    /// @dev Requires the tournament to be open.
    modifier whileTournamentOpen()
    {
        // TODO: Implement me!
        require(tournamentOpen);

        /* Sam's logic
        * Logic for active vs. inactive tournaments
        * tournamentOpen = true;
        * if(tournamentClosedTime <= now){
        *     tournamentOpen = false;
        * }

            if(tournamentOpen == true){
        */

        /*
         *   Max's logic: 
         *   if(maxRounds > 0)
         *   {
         *
         *   }
         *   else if(roundEndTime < now)
         *   {
         *       require(tournamentOpen);
         *   }
         */

         _;
    }

    /*
     * Setter Methods
     */

     // TODO: Implement setters.

    /*
     * Access Control Methods
     */

    /// @dev Returns whether or not the sender is the owner of this tournament.
    /// @param _sender Explicit sender address.
    /// @return Whether or not the sender is the owner.
    function isOwner(address _sender) public view returns (bool)
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
    function roundIsOpen() public view returns (bool)
    {
        return rounds[rounds.length-1].roundIsOpen();
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
    function openTournament() public
    {
        // Why do we have to do this? Why can't we use
        // a modifier?
        require((msg.sender == platformAddress) || (msg.sender == owner));
        // TODO: Uncomment.
        //uint allowedMTX = MatryxToken(matryxTokenAddress).allowance(msg.sender, this);
        //require(allowedMTX >= BountyMTX);
        //require(MatryxToken(matryxTokenAddress).transferFrom(msg.sender, this, BountyMTX));
        
        // Implement me!
        tournamentOpen = true;
        MatryxPlatform(platformAddress).invokeTournamentOpenedEvent(owner, this, name, externalAddress, BountyMTX, entryFee);
    }

    /// @dev Chooses the winner for the round.
    /// @param _submissionIndex Index of the winning submission
    function chooseWinner(uint256 _submissionIndex) public platformOrOwner
     {
        tournamentOpen = false;
 
        Round round = rounds[rounds.length-1];
        round.chooseWinningSubmission(_submissionIndex);
        //address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
        //MatryxToken.approve(winningAuthor, round.bountyMTX);

        RoundWinnerChosen(_submissionIndex);
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound() public returns (address _roundAddress)
    {
        uint256 roundBounty = BountyMTX.div(maxRounds);
        BountyMTX = BountyMTX - roundBounty;
        Round round = new Round(roundBounty);
        rounds.push(round);
        return address(round);
    }

    /// @dev Starts the latest round.
    /// @param _duration Duration of the round in seconds.
    function startRound(uint256 _duration) internal 
    {
        Round round = rounds[rounds.length-1];
        round.Start(_duration);
        RoundStarted(rounds.length-1);
    }

    function closeTournament(uint256 _submissionIndex) public onlyPlatform
    {
        Round round = rounds[rounds.length-1];


        address winningAuthor = round.getSubmissionAuthor(_submissionIndex);
        //MatryxToken.approve(winningAuthor, BountyMTX);

        tournamentOpen = false;
        MatryxPlatform(platformAddress).invokeTournamentClosedEvent(this, rounds.length, _submissionIndex);
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

    /// @dev Creates a submission under this tournament
    /// @param _name Name of the submission.
    /// @param _externalAddress Off-chain content hash of submission details (ipfs hash)
    /// @param _references Addresses of submissions referenced in creating this submission
    /// @param _contributors Contributors to this submission.
    /// @return (_roundIndex, _submissionIndex) Location of this submission.
    // function createSubmission(string _name, bytes32 _externalAddress, address[] _references, address[] _contributors) public onlyEntrant whileTournamentOpen whileRoundOpen returns (uint256 _roundIndex, uint256 _submissionIndex) {
    //     uint256 currentRoundIndex = rounds.length-1;
    //     Round round = rounds[currentRoundIndex];

    //     round.createSubmission(_name, _externalAddress, msg.sender,  _references, _contributors, false);
    //     numberOfSubmissions += 1;
    //     SubmissionLocation memory submissionLocation = SubmissionLocation(currentRoundIndex, round.numberOfSubmissions());
    //     giveEntrantAddressGetSubmissions[msg.sender].push(submissionLocation);

    //     return (currentRoundIndex, numberOfSubmissions-1);
    // }

    // TODO: Move to library.
    /// @dev Helper function to determine string emptiness.
    /// @param _string String to check whether is empty.
    /// @return Returns true if string is empty.
    function stringIsEmpty(string _string) public pure returns (bool)
    {
        bytes memory bytesString = bytes(_string);
        if (bytesString.length == 0) 
        {
            return true;
        }
        else
        {
            return false;
        }
    }
}