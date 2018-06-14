 pragma solidity ^0.4.18;
 pragma experimental ABIEncoderV2;

import "../libraries/strings/strings.sol";
import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
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
    bytes32[3] public title;
    bytes32[2] public descriptionHash;
    bytes32 public categoryHash;

    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    mapping(address=>bool) public isRound;
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

    constructor(LibConstruction.TournamentData memory tournamentData, LibConstruction.RoundData memory roundData, address _platformAddress, address _matryxTokenAddress, address _matryxRoundFactoryAddress, address _owner) 
    {
        //Clean inputs
        //require(_owner != 0x0);
        //require(tournamentData.title[0] != 0x0);
        //require(tournamentData.Bounty > 0);
        //require(_matryxRoundFactoryAddress != 0x0);
        
        platformAddress = _platformAddress;
        matryxTokenAddress = _matryxTokenAddress;
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;

        timeCreated = now;
        // Identification
        owner = _owner;
        categoryHash = tournamentData.categoryHash;
        title[0] = tournamentData.title_1;
        title[1] = tournamentData.title_2;
        title[2] = tournamentData.title_3;
        descriptionHash[0] = tournamentData.contentHash_1;
        descriptionHash[1] = tournamentData.contentHash_2;
        // Reward and fee
        Bounty = tournamentData.Bounty;
        //BountyLeft = Bounty;
        entryFee = tournamentData.entryFee;

        createRound(roundData);
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

    event NewRound(uint256 _startTime, uint256 _endTime, uint256 _reviewDuration, address _roundAddress, uint256 _roundNumber);
    //event RoundStarted(uint256 _roundIndex);
    // Fired at the end of every round, one time per submission created in that round
    event SubmissionCreated(uint256 _roundIndex, address _submissionAddress);
    event RoundWinnersChosen(address[] _submissionAddresses);

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
    /// @dev Returns the state of the tournament. One of:
    /// RoundNotYetOpen, RoundOpen, RoundInReview, TournamentClosed, RoundAbandoned
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

    function getTitle() public view returns (bytes32[3] _title)
    {
        return title;
    }

    function getCategory() public view returns (string _category)
    {
        return IMatryxPlatform(platformAddress).hashForCategory(categoryHash);
    }

    /// @dev Returns the external address of the tournament.
    /// @return _descriptionHash Off-chain content hash of tournament details (ipfs hash)
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash)
    {
        return descriptionHash;
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

    function setAll(LibConstruction.TournamentModificationData tournamentData)
    {
        if(tournamentData.title[0] != 0x0)
        {
            title = title;
        }
        if(tournamentData.contentHash.length != 0)
        {
            descriptionHash = tournamentData.contentHash;
        }
        if(tournamentData.entryFeeChanged)
        {
            entryFee = tournamentData.entryFee;
        }
    }

    function setTitle(bytes32[3] _title) public onlyOwner
    {
        title = _title;
    }

    function setDescriptionHash(bytes32[2] _descriptionHash) public onlyOwner
    {
        descriptionHash = _descriptionHash;
    }

    function setEntryFee(uint256 _entryFee) public onlyOwner
    {
        entryFee = _entryFee;
    }

    function setCategory(string _category) public onlyOwner
    {
        // if(!category.toSlice().empty())
        // {
        //     revert();
        // }
        // revert();
        // category = _category;
    }

    /*
     * Tournament Admin Methods
     */

    /// @dev Chooses the winner(s) of the current round. If this is the last round, 
    //       this method will also close the tournament.
    /// @param _submissionAddresses The winning submission addresses
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
    /// @param roundData Information with which to create the next round. Includes:
    ///   _start: (Ignored)
    ///   _end:   The end time (seconds from unix epoch) of the next round
    ///   _reviewDuration: The duration of time that will be allotted to review the next round
    ///   _bountyMTX: The amount of MTX that can be won during the next round
    function closeRound(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData roundData) public onlyOwner
    {
        // Round must be in review to close
        require(getState() == uint256(TournamentState.RoundInReview), "Round is not in review.");
        // TODO: Create big red button (new method)

        // Choose the winning submission(s) on the current round
        IMatryxRound(rounds[rounds.length-1]).chooseWinningSubmissions(_submissionAddresses, _rewardDistribution);

        // Event to notify web3 of the winning submission address
        emit RoundWinnersChosen(_submissionAddresses);

        // If there's no bounty left, end the tournament
        if(remainingBounty() == 0)
        {
            closeTournament(_submissionAddresses, _rewardDistribution);
            IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(rounds.length, _submissionAddresses, _rewardDistribution, IMatryxRound(rounds[rounds.length-1]).getBounty());
        }
        else
        {
            roundData.start = 0;
            createRound(roundData);
        }
    }

    // @dev Chooses the winner of the tournament.
    function closeTournament(address[] _submissionAddresses, uint256[] _rewardDistribution) public onlyOwner
    {
        // TODO: Validate that this is done.
        require(getState() == uint256(TournamentState.RoundInReview));
        //Transfer the remaining MTX in the tournament to the current round
        require(IMatryxToken(matryxTokenAddress).transfer(rounds[rounds.length-1], remainingBounty()));
        IMatryxRound(rounds[rounds.length-1]).chooseWinningSubmissions(_submissionAddresses, _rewardDistribution);
        emit RoundWinnersChosen(_submissionAddresses);
        IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(rounds.length, _submissionAddresses, _rewardDistribution, IMatryxRound(rounds[rounds.length-1]).getBounty());
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibConstruction.RoundData roundData) private returns (address _roundAddress)
    {
        //require((roundData.start >= now && roundData.start < roundData.end), "Time parameters are invalid.");

        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress;

        // If a bounty wasn't specified
        uint256 remaining = remainingBounty();
        if(roundData.bounty == 0x0)
        {
            // Use the last one
            roundData.bounty = IMatryxRound(rounds[rounds.length-1]).getBounty();
        }
        // If its more than what's left, use what's left.
        if(roundData.bounty > remaining)
        {
            roundData.bounty = remaining;
        }

        newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, roundData);
        // Transfer the round bounty to the round.

        if(rounds.length > 1)
        {
            IMatryxToken(matryxTokenAddress).transfer(newRoundAddress, roundData.bounty);
        }

        isRound[newRoundAddress] = true;
        rounds.push(newRoundAddress);

        // Triggers Event displaying start time, end, address, and round number
        emit NewRound(roundData.start, roundData.end, roundData.reviewDuration, newRoundAddress, rounds.length);

        return newRoundAddress;
    }

    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public onlyPlatform
    {
        IMatryxToken(matryxTokenAddress).transfer(rounds[_roundIndex], _bountyMTX);
    }

    // @dev Returns the remaining bounty the tournament is able to award
    function remainingBounty() public view returns (uint256)
    {
        return IMatryxToken(matryxTokenAddress).balanceOf(this);
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
        // UNCOMMENT THESE LATER - TODO: Fix matryxToken part
        // require(matryxToken.allowance(_entrantAddress, this) >= entryFee);

        bool transferSuccess = matryxToken.transferFrom(_entrantAddress, this, entryFee);
        if(transferSuccess)
        {
            //Finally, change the tournament's state to reflect the user entering.
            addressToIsEntrant[_entrantAddress].exists = true;
            addressToIsEntrant[_entrantAddress].value = entryFee;
            allEntrants.push(_entrantAddress);
        }

        return transferSuccess;
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

    function createSubmission(LibConstruction.SubmissionData submissionData) public onlyEntrant onlyPeerLinked(msg.sender) whileTournamentOpen returns (address _submissionAddress)
    {
        // This check is critical for MatryxPeer.
        address peerAddress = IMatryxPlatform(platformAddress).peerAddress(submissionData.owner);
        require(peerAddress != 0x0);

        address submissionAddress = IMatryxRound(rounds[rounds.length-1]).createSubmission(peerAddress, submissionData);
        // Send out reference requests to the authors of other submissions
        IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(submissionAddress, submissionData.references);

        if(numberOfSubmissions == 0)
        {
            IMatryxPlatform(platformAddress).invokeTournamentOpenedEvent(owner, title[0], title[1], title[2], descriptionHash[0], descriptionHash[1], Bounty, entryFee);
        }
        numberOfSubmissions = numberOfSubmissions.add(1);
        entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress] = uint256_optional({exists:true, value:entrantToSubmissions[msg.sender].length});
        entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform(platformAddress).updateSubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }
}