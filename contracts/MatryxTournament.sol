pragma solidity ^0.4.18;

import "../libraries/strings/strings.sol";
import "../libraries/math/SafeMath.sol";
import "../interfaces/IMatryxPlatform.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/factories/IMatryxRoundFactory.sol";
import "../interfaces/IMatryxRound.sol";
import "../interfaces/IMatryxToken.sol";
import "./Ownable.sol";

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
    bytes public externalAddress;
    string public category;

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
    uint256 public Bounty;
    uint256 public BountyLeft;
    uint256 public entryFee;

    // address roundDelegate;
    // bytes4 fnSelector_chooseWinner = bytes4(keccak256("chooseWinner(address)"));
    // bytes4 fnSelector_createRound = bytes4(keccak256("createRound(uint256)"));
    // bytes4 fnSelector_startRound = bytes4(keccak256("startRound(uint256)"));

    // TODO: Automatic round creation mechanism

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address=>address[]) private entrantToSubmissions;
    mapping(address=>mapping(address=>uint256_optional)) private entrantToSubmissionToSubmissionIndex;
    mapping(address=>uint256_optional) private addressToIsEntrant;
    address[] private allEntrants;

    function MatryxTournament(address _platformAddress, address _matryxTokenAddress, address _matryxRoundFactoryAddress, address _owner, string _category, string _tournamentTitle, bytes _externalAddress, uint256 _Bounty, uint256 _entryFee) public {
        //Clean inputs
        require(_owner != 0x0);
        //require(!_tournamentName.toSlice().empty());
        require(_Bounty > 0);
        require(_matryxRoundFactoryAddress != 0x0);
        
        platformAddress = _platformAddress;
        matryxTokenAddress = _matryxTokenAddress;
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;

        timeCreated = now;
        // Identification
        owner = _owner;
        category = _category;
        title = _tournamentTitle;
        externalAddress = _externalAddress;
        // Reward and fee
        Bounty = _Bounty;
        BountyLeft = _Bounty;
        entryFee = _entryFee;

        // roundDelegate = IMatryxPlatform(platformAddress).getRoundLibAddress();
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

    event NewRound(uint256 _startTime, uint256 _endTime, uint256 _reviewPeriod, address _roundAddress, uint256 _roundNumber);
    //event RoundStarted(uint256 _roundIndex);
    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, address _submissionAddress);
    event RoundWinnerChosen(address _submissionAddress);

    /// @dev Allows rounds to invoke SubmissionCreated events on this tournament.
    /// @param _submissionAddress Address of the submission.
    function invokeSubmissionCreatedEvent(address _submissionAddress) public onlyRound
    {
        emit SubmissionCreated(rounds.length-1, _submissionAddress);
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

    // modifier onlySubmission(address _submissionAddress, address _author)
    // {
    //     // If the submission does not exist,
    //     // the address of the submission we return will not be msg.sender
    //     // It will either be 
    //     // 1) The first submission, or
    //     // 2) all 0s from having deleted it previously.
    //     uint256 indexOfSubmission = entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].value;
    //     address submissionAddress = entrantToSubmissions[_author][indexOfSubmission];
    //     require(_submissionAddress == msg.sender);
    //     _;
    // }

    modifier onlyPeerLinked(address _sender)
    {
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        require(platform.hasPeer(_sender));
        _;
    }

    /// @dev Requires the function caller to be an entrant.
    modifier onlyEntrant()
    {
        bool senderIsEntrant = addressToIsEntrant[msg.sender].exists;
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
        require(getState() == uint256(TournamentState.RoundOpen));
        _;
    }

    // /// @dev Requires the tournament to be open.
    // modifier duringReviewPeriod()
    // {
    //     // TODO: Finish me!
    //     require(isInReview());
    //     _;
    // }

    // modifier whileRoundsLeft()
    // {
    //     require(rounds.length < maxRounds);
    //     _;
    // }

    // modifier whileBountyLeft(uint256 _nextRoundBounty)
    // {
    //     require(BountyLeft.sub(_nextRoundBounty) >= 0);
    //     _;
    // }

    /*
    * State Maintenance Methods
    */

    function removeSubmission(address _submissionAddress, address _author) public onlyPlatform returns (bool)
    {
        require(entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].exists);
        numberOfSubmissions = numberOfSubmissions.sub(1);
        delete entrantToSubmissions[_author][entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].value];
        delete entrantToSubmissionToSubmissionIndex[_author][_submissionAddress];
        return true;
    }

    /*
     * Access Control Methods
     */

    /// @dev Returns whether or not the sender is an entrant in this tournament
    /// @param _sender Explicit sender address.
    /// @return Whether or not the sender is an entrant in this tournament.
    function isEntrant(address _sender) public view returns (bool)
    {
        return addressToIsEntrant[_sender].exists;
    }

    enum TournamentState { RoundNotYetOpen, RoundOpen, RoundInReview, TournamentClosed, RoundAbandoned}



    //
    function getState() public view returns (uint256)
    {
        return IMatryxRound(rounds[rounds.length-1]).getState();
    }

    /*
     * Getter Methods
     */

    function getPlatform() public view returns (address _platformAddress)
    {
        return platformAddress;
    }

    function getTitle() public view returns (string _title)
    {
        return title;
    }

    function getCategory() public view returns (string _category)
    {
        return category;
    }

    /// @dev Returns the external address of the tournament.
    /// @return _externalAddress Off-chain content hash of tournament details (ipfs hash)
    function getExternalAddress() public view returns (bytes _externalAddress)
    {
        return externalAddress;
    }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress)
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

    function setExternalAddress(bytes _externalAddress) public onlyOwner
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
        require(_newMaxRounds > rounds.length);
        maxRounds = _newMaxRounds;
    }

    function setCategory(string _category) public onlyOwner
    {
        // if(!category.toSlice().empty())
        // {
        //     revert();
        // }
        //revert();
        category = _category;
    }

    /*
     * Tournament Admin Methods
     */

    /// @dev Chooses the winner for the round. If this is the last round, closes the tournament.
    /// @param _submissionAddress Address of the winning submission
    /// @param _end The end time of the the new round round
    /// @param _reviewPeriod The time designated to review the next round
    /// @param _bountyMTX The amount of Matryx Tokens assigned to the winner of the next round
    function closeRound(address _submissionAddress, uint256 _end, uint256 _reviewPeriod, uint256 _bountyMTX) public onlyOwner
    {

        //State must be in Review
        require(getState() == uint256(TournamentState.RoundInReview), "State isn't in review Period");
        // TODO: Create big red button (new method)
        // TODO: Validate that this is done.

        // End the round.
        // What does this line do?
        IMatryxRound(rounds[rounds.length-1]).chooseWinningSubmission(_submissionAddress);

        //Event to notify web3 of the winning submission address
        emit RoundWinnerChosen(_submissionAddress);

        // If there's no bounty left, end the tournament //TODO: else create a new round and start it right now
        if(remainingBounty() == 0 || rounds.length == maxRounds)s
        {
            tournamentOpen = false;
            //closeTournament(_submissionAddress);
            IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(address(this), rounds.length, _submissionAddress, IMatryxRound(rounds[rounds.length-1]).getBounty());
        }
        else
        {
            createRound(now, _end, _reviewPeriod, _bountyMTX);
        }
    }

    // @dev Chooses the winner of the tournament.
    function closeTournament(address _submissionAddress) public onlyOwner
    {
        // TODO: Validate that this is done.
        require(getState() == uint256(TournamentState.RoundInReview));
        //Transfer the remaining MTX in the tournament to the current round
        require(IMatryxToken(matryxTokenAddress).transfer(rounds[rounds.length-1], remainingBounty()));
        tournamentOpen = false;
        IMatryxRound(rounds[rounds.length-1]).chooseWinningSubmission(_submissionAddress);
        emit RoundWinnerChosen(_submissionAddress);
        IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(address(this), rounds.length, _submissionAddress, IMatryxRound(rounds[rounds.length-1]).getBounty());
    }


    // @dev Big Red Button allows the user to cancel the tournament whenever they please
    function bigRedButton(address _tournamentAddress) public onlyOwner returns (bool successfullyCanceled) {
        return true;
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(uint256 _start, uint256 _end, uint256 _reviewPeriod, uint256 _bountyMTX) public onlyOwner returns (address _roundAddress)
    {
        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        address newRoundAddress;

        require((_start <= now && now < _end),"Time Parameters are Invalid");
        // If a bounty wasn't specified
        uint256 remaining = remainingBounty();
        if(_bountyMTX == 0x0)
        {
            // Use the last one
            _bountyMTX = IMatryxRound(rounds[rounds.length-1]).getBounty();
        }
        // If its more than is left, use what's left.
        if(_bountyMTX < remaining)
        {
            _bountyMTX = remaining;
        }

        //If the next round is the last round
        if(rounds.length == 0)
        {
            // Set a flag
            openTournament();
        }

        newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, _start, _end, _reviewPeriod, _bountyMTX);
        // Transfer the round bounty to the round.
        matryxToken.transfer(newRoundAddress, _bountyMTX);

        isRound[newRoundAddress] = true;
        rounds.push(newRoundAddress);

        // Triggers Event displaying start time, end, address, and round number
        emit NewRound(_start, _end, _reviewPeriod, newRoundAddress, rounds.length);

        return newRoundAddress;
    }

    // @dev Returns the remaining bounty the tournament is able to award
    function remainingBounty() public view returns (uint256)
    {
        return IMatryxToken(matryxTokenAddress).balanceOf(this);
    }

    event platfromExists(address _platformAddress);

    /// @dev Opens this tournament up to submissions; called by startRound.
    function openTournament() //internal //UNCOMMENT THIS LATER
    {
        tournamentOpen = true;
        IMatryxPlatform platform = IMatryxPlatform(platformAddress);
        emit platfromExists(platformAddress);
        platform.invokeTournamentOpenedEvent(owner, this, title, externalAddress, Bounty, entryFee);
    }

    /*
     * Entrant Methods
     */

    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(address _entrantAddress) public onlyPlatform whileTournamentOpen returns (bool _success)
    {
        if(addressToIsEntrant[_entrantAddress].exists == true)
        {
            return false;
        }

        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        //UNCOMMENT THESE LATER - TODO: Fix matryxToken part
        //require(matryxToken.allowance(_entrantAddress, this) >= entryFee);
        //bool transferSuccess = matryxToken.transferFrom(_entrantAddress, this, entryFee);

        //if(transferSuccess)
        //{
            // Finally, change the tournament's state to reflect the user entering.
        addressToIsEntrant[_entrantAddress].exists = true;
        addressToIsEntrant[_entrantAddress].value = entryFee;
        allEntrants.push(_entrantAddress);
        //}

        //return transferSuccess;
        return true;
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return entryFee;
    }

    // function collectEntryFee() public returns (bool)
    // {
    //     IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
    //     bool success = matryxToken.transfer(msg.sender, addressToIsEntrant[msg.sender].value);
    //     if(success)
    //     {
    //         addressToIsEntrant[msg.sender].value = 0;
    //         return true;
    //     }

    //     return false;
    // }

    function createSubmission(string _title, address _owner, bytes _externalAddress, address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references) public onlyEntrant onlyPeerLinked(msg.sender) whileTournamentOpen returns (address _submissionAddress)
    {
        // This check is critical for MatryxPeer.
        address peerAddress = IMatryxPlatform(platformAddress).peerAddress(_owner);
        require(peerAddress != 0x0);

        address submissionAddress = IMatryxRound(rounds[rounds.length-1]).createSubmission(_title, _owner, peerAddress, _externalAddress, _references, _contributors, _contributorRewardDistribution);
        // Send out reference requests to the authors of other submissions
        IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(submissionAddress, _references);

        numberOfSubmissions = numberOfSubmissions.add(1);
        entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress] = uint256_optional({exists:true, value:entrantToSubmissions[msg.sender].length});
        entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform(platformAddress).updateSubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }
}