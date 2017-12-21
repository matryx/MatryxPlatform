pragma solidity ^0.4.18;

import './Ownable.sol';
import './Round.sol';
import './MatryxToken.sol';

///Creating a Tournament and the functionality
contract Tournament is Ownable {

    //Platform identification
    address public platformAddress;
    address public matryxTokenAddress;

    //Tournament identification
    string name;
    address public owner;
    string public tournamentName;
    bytes32 public externalAddress;

    // Timing
    uint256 public timeCreated;
    uint256 public tournamentStartTime;
    Round[] public rounds;
    uint256 public reviewPeriod;
    uint256 public endOfTournamentTime;
    uint public maxRounds = 1;
    bool public tournamentOpen = true;

    // Reward and fee
    uint public MTXReward;
    uint256 public entryFee;

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address => SubmissionLocation[]) private giveEntrantAddressGetSubmissions;
    mapping(address => bool) private addressToIsEntrant;

    // Tournament Constructor
    function Tournament(address _owner, string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee) public {
        //Clean inputs
        require(_owner != 0x0);
        require(!stringIsEmpty(_tournamentName));
        require(_MTXReward > 0);
        
        platformAddress = msg.sender;
        timeCreated = now;
        // Identification
        owner = _owner;
        tournamentName = _tournamentName;
        externalAddress = _externalAddress;
        // Reward and fee
        MTXReward = _MTXReward;
        entryFee = _entryFee;
    }

    // ----------------- Structs -------------------

    struct SubmissionLocation
    {
        uint256 roundIndex;
        uint256 submissionIndex;
    }

    // ----------------- Events --------------------

    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, uint256 _submissionIndex);

    function TriggerSubmissionCreatedEvent(uint256 _roundIndex, uint256 _submissionIndex) public
    {
        SubmissionCreated(_roundIndex, _submissionIndex);
    }

    // ----------------- Modifiers -----------------

    // Modifier requiring function caller to be the platform 
    modifier onlyPlatform()
    {
        require(platformAddress == msg.sender);
        _;
    }

    // Modifier requiring function caller to be an entrant
    modifier onlyEntrant()
    {
        bool senderIsEntrant = addressToIsEntrant[msg.sender];
        require(senderIsEntrant);
        _;
    }

    // Modifier requiring the round to be open
    modifier whileRoundOpen()
    {
        // TODO: Implement me!
        require(rounds[rounds.length-1].roundIsOpen());
        _;
    }

    // Modifier requiring the tournament to be open
    modifier whileTournamentOpen()
    {
        // TODO: Implement me!
        require(tournamentOpen);

        /* Sam's logic
        * Logic for active vs. inactive tournaments
        * tournamentOpen = true;
        * if(endOfTournamentTime <= now){
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

    // ----------------- Setter Methods -----------------

        // TODO: Move into setters.

        // require(_tournamentStartTime >= now);
        // tournamentStartTime = _tournamentStartTime;
        // require(_roundStartTime > now);
        // roundStartTime = _roundStartTime;
        // require(_roundEndTime > now);
        // roundEndTime = _roundEndTime;
        // require(_reviewPeriod != 0);
        // reviewPeriod = _reviewPeriod;
        // require(_endOfTournamentTime >  now);
        // endOfTournamentTime = _endOfTournamentTime;
        // require(_currentRound >= 0);
        // currentRound = _currentRound;
        // require(_maxRounds >= 0);
        // maxRounds = _maxRounds;

    // ----------------- Getter Methods -----------------

    // Returns true if a given address is the owner (an owner...?) of this tournament
    function isOwner(address _sender) public view returns (bool)
    {
        bool senderIsOwner = _sender == owner;
        return senderIsOwner;
    }

    function isEntrant(address _sender) public view returns (bool)
    {
        return addressToIsEntrant[_sender];
    }

    // Returns true if the tournament is open
    function tournamentOpen() public view returns (bool)
    {
        return tournamentOpen;
    }

    // Returns the external address of the tournament
    function getExternalAddress() public view returns (bytes32)
    {
        return externalAddress;
    }

    function currentRound() public constant returns (uint256)
    {
        return rounds.length;
    }

    function mySubmissions() public view returns (SubmissionLocation[])
    {
        return giveEntrantAddressGetSubmissions[msg.sender];
    }

    function submissionCount() public view returns (uint256)
    {
        return numberOfSubmissions;
    }

    // ----------------- Tournament Administration Methods -----------------

    // TODO: Refactor so that the owner is actually the owner and not the platform.

    // Called by the owner to open the tournament
    function openTournament(uint256 _MTXReward) public
    {
        uint allowedMTX = MatryxToken(matryxTokenAddress).allowance(msg.sender, this);
        require(allowedMTX >= _MTXReward);
        require(MatryxToken(matryxTokenAddress).transferFrom(msg.sender, this, _MTXReward));
        MTXReward = _MTXReward;
        // Why do we have to do this? Why can't we use
        // the 'onlyOwner' modifier?
        require(msg.sender == owner);
        // TODO: Implement me!
        tournamentOpen = true;
    }

    // Updates the submissions visible via the SubmissionViewer
    function updatePublicSubmissions() public pure
    {
        // TODO: Implement me!
        // Foreach submission made in a previous round,
        // send an event from 
    }

    // To be called by the tournament owner to choose a tournament winner
    // TODO: Implement me!
    function chooseWinner() public
    {
        // Why do we have to do this? Why can't we use
        // the 'onlyOwner' modifier?
        require(msg.sender == owner);
        
        tournamentOpen = false;
    }

    // ----------------- Entrant Methods -----------------

    // Enters the user into the tournament and returns whether or
    // not they were successfully entered. This method will return false
    // in the case that the user has already entered into the tournament
    function enterUserInTournament(address _entrantAddress) public onlyPlatform returns (bool success)
    {
        if(addressToIsEntrant[_entrantAddress] == false)
        {
            return false;
        }

        addressToIsEntrant[_entrantAddress] = true;
        return true;
    }

    // Returns the fee in MTX to be payed by a prospective entrant
    // to the tournament
    function getEntryFee() public view returns (uint256)
    {
        return entryFee;
    }

    // Creates a submission under this tournament
    function createSubmission(string _name, bytes32 _externalAddress, address[] _references, address[] _contributors) public onlyEntrant whileRoundOpen whileTournamentOpen returns (SubmissionLocation _submissionLocation) {
        uint256 currentRoundIndex = rounds.length-1;
        Round round = rounds[currentRoundIndex];

        round.createSubmission(_name, _externalAddress, msg.sender,  _references, _contributors, false);
        numberOfSubmissions += 1;
        SubmissionLocation memory submissionLocation = SubmissionLocation(currentRoundIndex, round.numberOfSubmissions());
        giveEntrantAddressGetSubmissions[msg.sender].push(submissionLocation);

        return submissionLocation;
    }

    // Helper function.
    // TODO: Move to library.
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
} // end of Tournament contract