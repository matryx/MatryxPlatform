pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/strings/strings.sol";
import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
//import "../libraries/interfaces/tournament/iLibTournamentStateManagement.sol";
import "../libraries/tournament/LibTournamentStateManagement.sol";
import "../libraries/tournament/LibTournamentAdminMethods.sol";
import "../libraries/tournament/LibTournamentEntrantMethods.sol";
import "../libraries/LibEnums.sol";
import "../interfaces/IMatryxPlatform.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/IMatryxSubmission.sol";
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
    address public matryxRoundFactoryAddress;

    // TODO: Create setter for this (resume here for upgrade system.)
    // address public libTournamentStateManagement;

    //Tournament identification
    LibConstruction.TournamentData data;
    LibTournamentStateManagement.StateData stateData;
    // Submission tracking
    LibTournamentStateManagement.EntryData entryData;

    // address roundDelegate;
    // bytes4 fnSelector_chooseWinner = bytes4(keccak256("chooseWinner(address)"));
    // bytes4 fnSelector_createRound = bytes4(keccak256("createRound(uint256)"));
    // bytes4 fnSelector_startRound = bytes4(keccak256("startRound(uint256)"));

    constructor(address _owner, address _platformAddress, address _matryxRoundFactoryAddress, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData)
    {
        //Clean inputs
        require(_owner != 0x0);
        require(tournamentData.title[0] != 0x0);
        require(tournamentData.initialBounty > 0);
        require(_matryxRoundFactoryAddress != 0x0);

        platformAddress = _platformAddress;
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;

        // Identification
        owner = _owner;
        data = tournamentData;

        _createRound(roundData, false);
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
    modifier onlyPlatform() {
        require(msg.sender == platformAddress);
        _;
    }

    modifier onlyRound() {
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

    modifier onlyPeerLinked(address _sender) {
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

    modifier whileTournamentOpen()
    {
        require(getState() == uint256(LibEnums.TournamentState.Open));
        _;
    }

    modifier ifRoundHasFunds()
    {
        address currentRoundAddress;

        (,currentRoundAddress) = currentRound();
        require(IMatryxRound(currentRoundAddress).getState() != uint256(LibEnums.RoundState.Unfunded));
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

    function getTokenAddress() public view returns (address _matryxTokenAddress)
    {
        return IMatryxPlatform(platformAddress).getTokenAddress();
    }

    function getData() public view returns (LibConstruction.TournamentData _data)
    {
        return data;
    }

    /// @dev Returns bool indicating whether _address corresponds to an existing round or not
    function isRound(address _roundAddress) public view returns (bool _isRound)
    {
        return stateData.isRound[_roundAddress];
    }

    /// @dev Returns list of round addresses in the tournament
    function getRounds() public view returns (address[] _rounds)
    {
        return stateData.rounds;
    }

    function getCategory() public view returns (bytes32 _category)
    {
        return data.category;
    }

    function getTitle() public view returns (bytes32[3] _title)
    {
        return data.title;
    }

    // @dev Returns the external address of the tournament.
    // @return _descriptionHash Off-chain content hash of tournament details (ipfs hash)
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash)
    {
        return data.descriptionHash;
    }

    function getFileHash() public view returns (bytes32[2] _fileHash)
    {
        return data.fileHash;
    }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress)
    {
        return LibTournamentStateManagement.currentRound(stateData);
    }

    ///@dev Returns this tournament's bounty.
    function getBounty() public view returns (uint256 _tournamentBounty)
    {
        IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());
        return token.balanceOf(address(this)).sub(stateData.entryFeesTotal).add(stateData.roundBountyAllocation);
    }

    // @dev Returns the remaining bounty this tournament is able to award.
    function getBalance() public view returns (uint256 _tournamentBalance)
    {
        IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());
        return token.balanceOf(address(this)).sub(stateData.entryFeesTotal);
    }

    /// @dev Returns the fee in MTX to be payed by a prospective entrant.
    /// @return Entry fee for this tournament.
    function getEntryFee() public view returns (uint256)
    {
        return data.entryFee;
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

    function update(LibConstruction.TournamentModificationData tournamentData) public onlyOwner
    {
        data.update(tournamentData, platformAddress);
    }

    /// @dev Add additional funds to the tournament
    function addFunds(uint256 _fundsToAdd) public
    {
        uint256 tournamentState = this.getState();
        require(
            tournamentState == uint256(LibEnums.TournamentState.NotYetOpen) ||
            tournamentState == uint256(LibEnums.TournamentState.Open) ||
            tournamentState == uint256(LibEnums.TournamentState.OnHold));

        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        require(IMatryxToken(matryxTokenAddress).transferFrom(msg.sender, address(this), _fundsToAdd));
    }

    /*
     * Tournament Admin Methods
     */

    /// @dev Chooses the winner(s) of the current round. If this is the last round,
    //       this method will also close the tournament.
    /// @param _selectWinnersData Struct containing winning submission information including:
    ///        winningSubmissions: Winning submission addresses
    ///        rewardDistribution: Distribution indicating how to split the reward among the submissions
    ///        selectWinnerAction: SelectWinnerAction (DoNothing, StartNextRound, CloseTournament) indicating what to do after winner selection
    ///        rewardDistributionTotal: (Unused)
    /// @param _roundData Struct containing data for the next round including:
    ///   start: Start time (seconds since unix-epoch) for next round
    ///   end: End time (seconds since unix-epoch) for next round
    ///   reviewPeriodDuration: Number of seconds to allow for winning submissions to be selected in next round
    ///   bounty: Bounty in MTX for next round
    ///   closed: (Unused)
    function selectWinners(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public onlyOwner
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        LibTournamentAdminMethods.selectWinners(stateData, platformAddress, matryxTokenAddress, _selectWinnersData, _roundData);
    }

    /// @dev modifies the future "Ghost" Round Information
    function editGhostRound(LibConstruction.RoundData _roundData) public onlyOwner
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        LibTournamentAdminMethods.editGhostRound(stateData, _roundData, matryxTokenAddress);
    }

    ///@dev Allocates some of this tournament's balance to the current round
    function allocateMoreToRound(uint256 _mtxAllocation) public onlyOwner
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
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
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        LibTournamentAdminMethods.stopTournament(stateData, platformAddress, matryxTokenAddress);
    }

    /// @dev Creates a new round.
    /// @return The new round's address.
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public onlyRound returns (address _roundAddress)
    {
        return _createRound(roundData, _automaticCreation);
    }

    function _createRound(LibConstruction.RoundData roundData, bool _automaticCreation) private returns (address _roundAddress)
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        return LibTournamentAdminMethods.createRound(stateData, platformAddress, matryxTokenAddress, matryxRoundFactoryAddress, roundData, _automaticCreation);
    }

    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public onlyPlatform
    {
        stateData.roundBountyAllocation = stateData.roundBountyAllocation.add(_bountyMTX);
        IMatryxToken token = IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress());
        require(token.transfer(stateData.rounds[_roundIndex], _bountyMTX));
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

    function collectMyEntryFee() public
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        LibTournamentEntrantMethods.collectMyEntryFee(stateData, entryData, matryxTokenAddress);
    }

    function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public onlyEntrant onlyPeerLinked(msg.sender) ifRoundHasFunds whileTournamentOpen returns (address _submissionAddress)
    {
        address currentRoundAddress;
        (, currentRoundAddress) = LibTournamentStateManagement.currentRound(stateData);
        address newSubmission = LibTournamentEntrantMethods.createSubmission(platformAddress, currentRoundAddress, entryData, submissionData);

        if (contribsAndRefs.contributors.length != 0 || contribsAndRefs.references.length != 0)
        {
            IMatryxSubmission(newSubmission).setContributorsAndReferences(contribsAndRefs);
        }
        // Send out reference requests to the authors of other submissions
        // IMatryxPlatform(platformAddress).handleReferenceRequestsForSubmission(newSubmission, contribsAndRefs.references);

        return newSubmission;
    }

    function withdrawFromAbandoned() public onlyEntrant
    {
        address matryxTokenAddress = IMatryxPlatform(platformAddress).getTokenAddress();
        LibTournamentEntrantMethods.withdrawFromAbandoned(stateData, entryData, matryxTokenAddress);
    }
}
