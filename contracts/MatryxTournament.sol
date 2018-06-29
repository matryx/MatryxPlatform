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
    // Platform identification
    address public platformAddress;
    address public matryxTokenAddress;
    address public matryxRoundFactoryAddress;

    //Tournament identification
    bytes32[3] public title;
    bytes32[2] public descriptionHash;
    bytes32[2] public fileHash;
    bytes32 public categoryHash;
    address public owner;
    string public category;
    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    address[] public rounds;
    mapping(address=>bool) public isRound;
    bool public closed;
    // Reward, entry fees and round bounty allocation
    uint256 public bounty;
    uint256 public entryFee;
    uint256 public entryFeesTotal;
    uint256 public roundBountyAllocation;
    bool hasBeenWithdrawnFrom;
    mapping(address=>bool) hasWithdrawn;

    // address roundDelegate;
    // bytes4 fnSelector_chooseWinner = bytes4(keccak256("chooseWinner(address)"));
    // bytes4 fnSelector_createRound = bytes4(keccak256("createRound(uint256)"));
    // bytes4 fnSelector_startRound = bytes4(keccak256("startRound(uint256)"));

    // Submission tracking
    uint256 numberOfSubmissions = 0;
    mapping(address=>address[]) private entrantToSubmissions;
    mapping(address=>mapping(address=>uint256_optional)) private entrantToSubmissionToSubmissionIndex;
    mapping(address=>uint256_optional) private addressToEntryFeePaid;
    uint256 numberOfEntrants;
    bool winnersChosen;

    constructor(string _category, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData, address _platformAddress, address _matryxTokenAddress, address _matryxRoundFactoryAddress, address _owner) 
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
        category = _category;
        title[0] = tournamentData.title_1;
        title[1] = tournamentData.title_2;
        title[2] = tournamentData.title_3;
        descriptionHash[0] = tournamentData.descriptionHash_1;
        descriptionHash[1] = tournamentData.descriptionHash_2;
        fileHash[0] = tournamentData.fileHash_1;
        fileHash[1] = tournamentData.fileHash_2;
        // Reward and fee
        bounty = tournamentData.bounty;
        entryFee = tournamentData.entryFee;

        createRound(roundData, false);
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

    event NewRound(uint256 _startTime, uint256 _endTime, uint256 _reviewPeriodDuration, address _roundAddress, uint256 _roundNumber);
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
        bool senderIsEntrant = addressToEntryFeePaid[msg.sender].exists;
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
        require(getState() == uint256(TournamentState.Open));
        _;
    }

    modifier ifRoundHasFunds()
    {
        // require((IMatryxRound(currentRound()[1]).getState()) != uint256(RoundState.Unfunded));
        address currentRoundAddress;

        (,currentRoundAddress) = currentRound();
        require(IMatryxRound(currentRoundAddress).getState() != uint256(RoundState.Unfunded));
        _;
    }

    modifier onlyOwner()
    {
        require(msg.sender == owner);
        _;
    }

    // /// @dev Requires the tournament to be open.
    // modifier duringReviewPeriod()
    // {
    //     // TODO: Finish me!
    //     require(isInReview());
    //     _;
    // }

    // TODO: Use MatryxToken
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
        return addressToEntryFeePaid[_sender].exists;
    }

    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum ParticipantType { Nonentrant, Entrant, Contributor, Author }
    /// @dev Returns the state of the tournament. One of:
    /// NotYetOpen, Open, Closed, Abandoned
    function getState() public view returns (uint256)
    {
        uint256 numberOfRounds;
        address roundAddress;
        (numberOfRounds, roundAddress) = currentRound();

        if(closed)
        {
            return uint256(TournamentState.Closed);
        }
        else if(numberOfRounds > 0)
        {
            uint256 roundState = IMatryxRound(roundAddress).getState();
            if(numberOfRounds != 1)
            {
                if(roundState == uint256(RoundState.Unfunded) || roundState == uint256(RoundState.Open) || roundState == uint256(RoundState.InReview)
                    || roundState == uint256(RoundState.HasWinners))
                {
                    return uint256(TournamentState.Open);
                }
                else if(roundState == uint256(RoundState.NotYetOpen))
                {
                    return uint256(TournamentState.OnHold);
                }
                else if(roundState == uint256(RoundState.Closed))
                {
                    return uint256(TournamentState.Closed);
                }
                else
                {
                    return uint256(TournamentState.Abandoned);
                }
            }
            else if(roundState == uint256(RoundState.NotYetOpen))
            {
                return uint256(TournamentState.NotYetOpen);
            }
            else if(roundState == uint256(RoundState.Unfunded) || roundState == uint256(RoundState.Open) || roundState == uint256(RoundState.InReview)
                    || roundState == uint256(RoundState.HasWinners))
            {
                return uint256(TournamentState.Open);
            }
            else if(roundState == uint256(RoundState.Closed))
            {
                return uint256(TournamentState.Closed);
            }
            else
            {
                return uint256(TournamentState.Abandoned);
            }
        }
        
        return 0;
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

    function getOwner() public view returns (address _owner)
    {
        return owner;
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
        if(rounds.length > 1 && 
           IMatryxRound(rounds[rounds.length-2]).getState() == uint256(RoundState.HasWinners) &&
           IMatryxRound(rounds[rounds.length-1]).getState() == uint256(RoundState.NotYetOpen))
        {
            return (rounds.length-1, rounds[rounds.length-2]);
        }
        else
        {
            return (rounds.length, rounds[rounds.length-1]);
        }
    }

    ///@dev Returns this tournament's bounty.
    function getBounty() public returns (uint256 _tournamentBounty)
    {  
        return IMatryxToken(matryxTokenAddress).balanceOf(address(this)).sub(entryFeesTotal).add(roundBountyAllocation);
    }

    // @dev Returns the remaining bounty this tournament is able to award.
    function getBalance() public returns (uint256 _tournamentBalance)
    {
        return IMatryxToken(matryxTokenAddress).balanceOf(address(this)).sub(entryFeesTotal);
    }

    ///@dev Returns the round that was created implicitly for the user after they chose the "DoNothing" option
    ///     when choosing their round winners.
    ///@return _ghostAddress Address of the upcoming round created during winner selection
    function getGhostRound() internal returns (uint256 _index, address _ghostAddress)
    {
        if(IMatryxRound(rounds[rounds.length-2]).getState() == uint256(RoundState.HasWinners) &&
           IMatryxRound(rounds[rounds.length-1]).getState() == uint256(RoundState.NotYetOpen))
        {
            return (rounds.length-1, rounds[rounds.length-1]);
        }

        return (0, address(0x0));
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
        return numberOfEntrants;
    }

    /*
     * Setter Methods
     */

    function update(string _category, LibConstruction.TournamentModificationData tournamentData) onlyOwner
    {
        // TODO: Update the category on the platform
        if(category.toSlice().empty() == false)
        {
            IMatryxPlatform(platformAddress).switchTournamentCategory(address(this), category, _category);
            category = _category;
        }
        if(tournamentData.title_1 != 0x0)
        {
            title[0] = tournamentData.title_1;
            title[1] = tournamentData.title_2;
            title[2] = tournamentData.title_3;
        }
        if(tournamentData.descriptionHash_1 != 0x0)
        {
            descriptionHash[0] = tournamentData.descriptionHash_1;
            descriptionHash[1] = tournamentData.descriptionHash_2;
        }
        if(tournamentData.fileHash_1 != 0x0)
        {
            fileHash[0] = tournamentData.fileHash_1;
            fileHash[1] = tournamentData.fileHash_2;
        }
        if(tournamentData.entryFeeChanged)
        {
            entryFee = tournamentData.entryFee;
        }
    }

    function updateTitle(bytes32[3] _title) public onlyOwner
    {
        title = _title;
    }

    function updateDescriptionHash(bytes32[2] _descriptionHash) public onlyOwner
    {
        descriptionHash = _descriptionHash;
    }

    function updateEntryFee(uint256 _entryFee) public onlyOwner
    {
        entryFee = _entryFee;
    }

    function updateCategory(string _category) public onlyOwner
    {
        require(_category.toSlice().empty() == false);
        IMatryxPlatform(platformAddress).switchTournamentCategory(address(this), category, _category);
        category = _category;
    }

    /*
     * Tournament Admin Methods
     */

    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
    /// @dev Chooses the winner(s) of the current round. If this is the last round, 
    //       this method will also close the tournament.
    /// @param _submissionAddresses The winning submission addresses
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
    function selectWinners(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public onlyOwner
    {
        // Round must be in to close
        address currentRoundAddress;
        (, currentRoundAddress) = currentRound();
        uint256 roundState = uint256(IMatryxRound(currentRoundAddress).getState());
        require(roundState == uint256(RoundState.InReview) || roundState == uint256(RoundState.HasWinners), "Round is not in review and winners have not been chosen.");

        // Event to notify web3 of the winning submission address
        emit RoundWinnersChosen(_submissionAddresses);
        IMatryxRound(currentRoundAddress).selectWinningSubmissions(_submissionAddresses, _rewardDistribution, _roundData, _selectWinnerAction);
        if(_selectWinnerAction == uint256(SelectWinnerAction.CloseTournament))
        {
            closeTournament();
        }
    }

    function editGhostRound(LibConstruction.RoundData _roundData) public onlyOwner
    {
        (uint256 ghostRoundIndex, address ghostRoundAddress) = getGhostRound();
        (,address currentRoundAddress) = currentRound();
        if(ghostRoundAddress != 0x0)
        {
            uint256 ghostRoundBounty = IMatryxRound(ghostRoundAddress).getBounty();
            if(_roundData.bounty > ghostRoundBounty)
            {
                // Transfer to ghost round
                uint256 addAmount = _roundData.bounty.sub(ghostRoundBounty);
                roundBountyAllocation = roundBountyAllocation.add(addAmount);
                require(IMatryxToken(matryxTokenAddress).transfer(ghostRoundAddress, addAmount));
            }
            else if(_roundData.bounty < ghostRoundBounty)
            {
                // Have ghost round transfer to the tournament
                uint256 subAmount = ghostRoundBounty.sub(_roundData.bounty);
                roundBountyAllocation = roundBountyAllocation.sub(subAmount);
                IMatryxRound(ghostRoundAddress).transferToTournament(subAmount);
            }

            IMatryxRound(ghostRoundAddress).editRound(IMatryxRound(rounds[ghostRoundIndex-1]).getEndTime(), _roundData);
        }
    }

    ///@dev Allocates some of this tournament's balance to the current round
    function allocateMoreToRound(uint256 _mtxAllocation) public onlyOwner
    {
        (, address currentRoundAddress) = currentRound();
        roundBountyAllocation = roundBountyAllocation.add(_mtxAllocation);
        require(IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, _mtxAllocation));
    }

    /// @dev This function should be called after the user selects winners for their tournament and chooses the "DoNothing" option
    function jumpToNextRound() public onlyOwner
    {
        (uint256 currentRoundIndex, address currentRoundAddress) = currentRound();
        IMatryxRound(currentRoundAddress).closeRound();
        IMatryxRound(rounds[currentRoundIndex+1]).startNow();
    }

    /// @dev This function closes the tournament after the tournament owner selects their winners with the "DoNothing" option
    function stopTournament() public onlyOwner
    {
        (,address currentRoundAddress) = currentRound();
        IMatryxRound(currentRoundAddress).closeRound();
        closeTournament();
    }

    // @dev Chooses the winner of the tournament.
    function closeTournament() private
    {
        address currentRoundAddress;
        (, currentRoundAddress) = currentRound();
        uint256 roundState = uint256(IMatryxRound(currentRoundAddress).getState());
        //Transfer the remaining MTX in the tournament to the current round
        uint256 remainingBalance = getBalance();
        roundBountyAllocation = roundBountyAllocation.add(remainingBalance);
        IMatryxToken(matryxTokenAddress).transfer(currentRoundAddress, remainingBalance);
        IMatryxRound(currentRoundAddress).transferAllToWinners(remainingBalance);
        IMatryxPlatform(platformAddress).invokeTournamentClosedEvent(rounds.length, IMatryxRound(currentRoundAddress).getBounty());
        
        closed = true;
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress)
    {
        // only this, the tournamentFactory or rounds can call createRound
        require(msg.sender == address(this) || msg.sender == IMatryxPlatform(platformAddress).getTournamentFactoryAddress() || isRound[msg.sender]);
        require((roundData.start >= now && roundData.start < roundData.end), "Time parameters are invalid.");

        IMatryxRoundFactory roundFactory = IMatryxRoundFactory(matryxRoundFactoryAddress);
        address newRoundAddress;

        if(_automaticCreation == false)
        {
            require(roundData.bounty > 0);
        }

        newRoundAddress = roundFactory.createRound(platformAddress, this, msg.sender, rounds.length, roundData);
        
        // Transfer the round bounty to the round.
        if(rounds.length != 0 && roundData.bounty != 0)
        {
            roundBountyAllocation = roundBountyAllocation.add(roundData.bounty);
            IMatryxToken(matryxTokenAddress).transfer(newRoundAddress, roundData.bounty);
        }
 
        rounds.push(newRoundAddress);
        isRound[newRoundAddress] = true;

        // Triggers Event displaying start time, end, address, and round number
        emit NewRound(roundData.start, roundData.end, roundData.reviewPeriodDuration, newRoundAddress, rounds.length);

        return newRoundAddress;
    }

    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public onlyPlatform
    {
        roundBountyAllocation = roundBountyAllocation.add(_bountyMTX);
        require(IMatryxToken(matryxTokenAddress).transfer(rounds[_roundIndex], _bountyMTX));
    }

    /*
     * Entrant Methods
     */

    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(address _entrantAddress) public onlyPlatform whileTournamentOpen returns (bool _success)
    {
        if(addressToEntryFeePaid[_entrantAddress].exists == true)
        {
            return false;
        }

        // Change the tournament's state to reflect the user entering.
        addressToEntryFeePaid[_entrantAddress].exists = true;
        addressToEntryFeePaid[_entrantAddress].value = entryFee;
        entryFeesTotal = entryFeesTotal.add(entryFee);
        numberOfEntrants = numberOfEntrants.add(1);

        (, address currentRoundAddress) = currentRound();
        IMatryxRound(currentRoundAddress).becomeEntrant(_entrantAddress);

        return true;
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return entryFee;
    }

    function collectMyEntryFee() public
    {
        returnEntryFeeToEntrant(msg.sender);
    }

    function returnEntryFeeToEntrant(address _entrant) internal
    {
        // Make sure entrants don't withdraw their entry fee early
        uint256 currentState = getState();
        (,address currentRoundAddress) = currentRound();
        require(IMatryxRound(currentRoundAddress).getParticipantType(_entrant) == uint256(ParticipantType.Entrant));

        IMatryxToken matryxToken = IMatryxToken(matryxTokenAddress);
        require(matryxToken.transfer(_entrant, addressToEntryFeePaid[_entrant].value));
        entryFeesTotal = entryFeesTotal.sub(addressToEntryFeePaid[_entrant].value);
        addressToEntryFeePaid[_entrant] = uint256_optional({exists: false, value: 0});
        numberOfEntrants = numberOfEntrants.sub(1);
        //TODO: remove from entrants array
        IMatryxRound(currentRoundAddress).becomeNonentrant(_entrant);
    }

    function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public onlyEntrant onlyPeerLinked(msg.sender) ifRoundHasFunds whileTournamentOpen returns (address _submissionAddress)
    {
        address peerAddress = IMatryxPlatform(platformAddress).peerAddress(submissionData.owner);

        address currentRoundAddress;
        (, currentRoundAddress) = currentRound();
        address submissionAddress = IMatryxRound(currentRoundAddress).createSubmission(_contributors, _contributorRewardDistribution, _references, peerAddress, submissionData);
        // Send out reference requests to the authors of other submissions
        IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(submissionAddress, _references);

        if(numberOfSubmissions == 0)
        {
            IMatryxPlatform(platformAddress).invokeTournamentOpenedEvent(owner, title[0], title[1], title[2], descriptionHash[0], descriptionHash[1], bounty, entryFee);
        }

        numberOfSubmissions = numberOfSubmissions.add(1);
        entrantToSubmissionToSubmissionIndex[msg.sender][submissionAddress] = uint256_optional({exists:true, value:entrantToSubmissions[msg.sender].length});
        entrantToSubmissions[msg.sender].push(submissionAddress);
        IMatryxPlatform(platformAddress).updateSubmissions(msg.sender, submissionAddress);
        
        return submissionAddress;
    }


    function withdrawFromAbandoned() public onlyEntrant
    {
        require(getState() == uint256(TournamentState.Abandoned), "This tournament is still valid.");
        require(!hasWithdrawn[msg.sender]);

        address currentRoundAddress;
        (, currentRoundAddress) = currentRound();
        // If this is the first withdrawal being made...
        if(IMatryxToken(matryxTokenAddress).balanceOf(currentRoundAddress) > 0)
        {
            uint256 roundBounty = IMatryxRound(currentRoundAddress).transferBountyToTournament();
            roundBountyAllocation = roundBountyAllocation.sub(roundBounty);
            returnEntryFeeToEntrant(msg.sender);
            require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, getBalance().div(numberOfEntrants).mul(2)));
        }
        else
        {
            returnEntryFeeToEntrant(msg.sender);
            require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, getBalance().mul(numberOfEntrants.sub(2)).div(numberOfEntrants).div(numberOfEntrants.sub(1))));
        }

        hasWithdrawn[msg.sender] = true;
    }
}