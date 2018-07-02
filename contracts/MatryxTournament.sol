 pragma solidity ^0.4.18;
 pragma experimental ABIEncoderV2;

import "../libraries/strings/strings.sol";
import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
//import "../libraries/interfaces/tournament/iLibTournamentStateManagement.sol";
import "../libraries/tournament/LibTournamentStateManagement.sol";
import "../libraries/tournament/LibTournamentAdminMethods.sol";
import "../libraries/tournament/LibTournamentEntrantMethods.sol";
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
    using LibTournamentAdminMethods for LibConstruction.TournamentData;
    
    // TODO: condense and put in structs
    // Platform identification
    address public platformAddress;
    address public matryxTokenAddress;
    address public matryxRoundFactoryAddress;

    // TODO: Create setter for this (resume here for upgrade system.)
    // address public libTournamentStateManagement;

    //Tournament identification
    address public owner;
    LibConstruction.TournamentData data;
    // Timing and State
    uint256 public timeCreated;
    uint256 public tournamentOpenedTime;
    LibTournamentStateManagement.StateData stateData;
    // Submission tracking
    LibTournamentStateManagement.EntryData entryData;

    // address roundDelegate;
    // bytes4 fnSelector_chooseWinner = bytes4(keccak256("chooseWinner(address)"));
    // bytes4 fnSelector_createRound = bytes4(keccak256("createRound(uint256)"));
    // bytes4 fnSelector_startRound = bytes4(keccak256("startRound(uint256)"));

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
        data = tournamentData;
        data.category = _category;

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
        emit SubmissionCreated(stateData.rounds.length-1, _submissionAddress);
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
        require(stateData.isRound[msg.sender]);
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
        bool senderIsEntrant = entryData.addressToEntryFeePaid[msg.sender].exists;
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
        require(entryData.entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].exists);
        entryData.numberOfSubmissions = entryData.numberOfSubmissions.sub(1);
        delete entryData.entrantToSubmissions[_author][entryData.entrantToSubmissionToSubmissionIndex[_author][_submissionAddress].value];
        delete entryData.entrantToSubmissionToSubmissionIndex[_author][_submissionAddress];
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
        return entryData.addressToEntryFeePaid[_sender].exists;
    }

    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum ParticipantType { Nonentrant, Entrant, Contributor, Author }
    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
    /// @dev Returns the state of the tournament. One of:
    /// NotYetOpen, Open, Closed, Abandoned
    function getState() public view returns (uint256)
    {
        return LibTournamentStateManagement.getState(stateData);
    }

    /*
     * Getter Methods
     */

    function getPlatform() public view returns (address _platformAddress)
    {
        return platformAddress;
    }

    function getData() public view returns (LibConstruction.TournamentData _data)
    {
        return data;
    }

    // function getTitle() public view returns (bytes32[3] _title)
    // {
    //     bytes32[3] memory title;
    //     title[0] = data.title_1;
    //     title[1] = data.title_2;
    //     title[2] = data.title_3;
    //     return title;
    // }

    // function getCategory() public view returns (string _category)
    // {
    //     // return IMatryxPlatform(platformAddress).hashForCategory(categoryHash);
    //     // TODO: Fix me
    //     return data.category;
    // }

    function getOwner() public view returns (address _owner)
    {
        return owner;
    }

    /// @dev Returns the external address of the tournament.
    /// @return _descriptionHash Off-chain content hash of tournament details (ipfs hash)
    // function getDescriptionHash() public view returns (bytes32[2] _descriptionHash)
    // {
    //     bytes32[2] memory descriptionHash;
    //     descriptionHash[0] = data.descriptionHash_1;
    //     descriptionHash[1] = data.descriptionHash_2;
    //     return descriptionHash;
    // }

    // function getFileHash() public view returns (bytes32[2] _fileHash)
    // {
    //     bytes32[2] memory fileHash;
    //     fileHash[0] = data.fileHash_1;
    //     fileHash[1] = data.fileHash_2;
    //     return fileHash;
    // }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress)
    {
        return LibTournamentStateManagement.currentRound(stateData);
    }

    ///@dev Returns this tournament's bounty.
    function getBounty() public returns (uint256 _tournamentBounty)
    {  
        return IMatryxToken(matryxTokenAddress).balanceOf(address(this)).sub(stateData.entryFeesTotal).add(stateData.roundBountyAllocation);
    }

    // @dev Returns the remaining bounty this tournament is able to award.
    function getBalance() public returns (uint256 _tournamentBalance)
    {
        return IMatryxToken(matryxTokenAddress).balanceOf(address(this)).sub(stateData.entryFeesTotal);
    }

    ///@dev Returns the round that was created implicitly for the user after they chose the "DoNothing" option
    ///     when choosing their round winners.
    ///@return _ghostAddress Address of the upcoming round created during winner selection
    function getGhostRound() internal returns (uint256 _index, address _ghostAddress)
    {
        return LibTournamentStateManagement.getGhostRound(stateData);
    }

    /// @dev Returns all of the sender's submissions to this tournament.
    /// @return (_roundIndices[], _submissionIndices[]) Locations of the sender's submissions.
    function mySubmissions() public view returns (address[])
    {
        address[] memory _mySubmissions = entryData.entrantToSubmissions[msg.sender];
        return _mySubmissions;
    }

    /// @dev Returns the number of submissions made to this tournament.
    /// @return _submissionCount Number of submissions made to this tournament.
    function submissionCount() public view returns (uint256 _submissionCount)
    {
        return entryData.numberOfSubmissions;
    }

    function entrantCount() public view returns (uint256 _entrantCount)
    {
        return entryData.numberOfEntrants;
    }

    /*
     * Setter Methods
     */

    function update(LibConstruction.TournamentModificationData tournamentData, string _category) public onlyOwner
    {
        data.update(tournamentData, _category, platformAddress);
    }

    /*
     * Tournament Admin Methods
     */

    /// @dev Chooses the winner(s) of the current round. If this is the last round, 
    //       this method will also close the tournament.
    /// @param _submissionAddresses The winning submission addresses
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
    function selectWinners(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public onlyOwner
    {
        LibTournamentAdminMethods.selectWinners(stateData, platformAddress, matryxTokenAddress, _submissionAddresses, _rewardDistribution, _roundData, _selectWinnerAction);
    }

    function editGhostRound(LibConstruction.RoundData _roundData) public onlyOwner
    {

        LibTournamentAdminMethods.editGhostRound(stateData, _roundData, matryxTokenAddress);
    }

    ///@dev Allocates some of this tournament's balance to the current round
    function allocateMoreToRound(uint256 _mtxAllocation) public onlyOwner
    {
        LibTournamentAdminMethods.allocateMoreToRound(stateData, _mtxAllocation, matryxTokenAddress);
    }

    /// @dev This function should be called after the user selects winners for their tournament and chooses the "DoNothing" option
    function jumpToNextRound() public onlyOwner
    {
        LibTournamentAdminMethods.jumpToNextRound(stateData);
    }

    /// @dev This function closes the tournament after the tournament owner selects their winners with the "DoNothing" option
    function stopTournament() public onlyOwner
    {
        LibTournamentAdminMethods.stopTournament(stateData, platformAddress, matryxTokenAddress);
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress)
    {
        LibTournamentAdminMethods.createRound(stateData, platformAddress, matryxTokenAddress, matryxRoundFactoryAddress, roundData, _automaticCreation);
    }

    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public onlyPlatform
    {
        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(_bountyMTX);
        require(IMatryxToken(matryxTokenAddress).transfer(stateData.rounds[_roundIndex], _bountyMTX));
    }

    /*
     * Entrant Methods
     */

    // LibTournamentEntrantMethods
    /// @dev Enters the user into the tournament.
    /// @param _entrantAddress Address of the user to enter.
    /// @return success Whether or not the user was entered successfully.
    function enterUserInTournament(address _entrantAddress) public onlyPlatform whileTournamentOpen returns (bool _success)
    {
        return LibTournamentEntrantMethods.enterUserInTournament(data, stateData, entryData, _entrantAddress);
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return data.entryFee;
    }

    function collectMyEntryFee() public
    {
        LibTournamentEntrantMethods.collectMyEntryFee(stateData, entryData, matryxTokenAddress);
    }

    function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.SubmissionData submissionData) public onlyEntrant onlyPeerLinked(msg.sender) ifRoundHasFunds whileTournamentOpen returns (address _submissionAddress)
    {
        if(entryData.numberOfSubmissions == 0)
        {
            IMatryxPlatform(platformAddress).invokeTournamentOpenedEvent(data.title_1, data.title_2, data.title_3, data.descriptionHash_1, data.descriptionHash_2, data.bounty, data.entryFee);
        }

        return LibTournamentEntrantMethods.createSubmission(stateData, entryData, platformAddress, _contributors, _contributorRewardDistribution, _references, submissionData);
    }

    function withdrawFromAbandoned() public onlyEntrant
    {
        LibTournamentEntrantMethods.withdrawFromAbandoned(stateData, entryData, matryxTokenAddress);
    }
}