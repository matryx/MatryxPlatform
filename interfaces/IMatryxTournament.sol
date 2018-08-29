pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";

interface IMatryxTournament
{
    function invokeSubmissionCreatedEvent(address _submissionAddress) public;
    function getPlatform() public view returns (address _platformAddress);
    function getTokenAddress() public view returns (address _matryxTokenAddress);

    function removeSubmission(address _submissionAddress, address _author) public;
    function isEntrant(address _address) public view returns (bool _isEntrant);
    function isRound(address _address) public view returns (bool _isRound);

    function getRounds() public view returns (address[] _rounds);
    function getState() public view returns (uint256 state);
    function getData() public view returns (LibConstruction.TournamentData _data);
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress);
    function getCategory() public view returns (bytes32 _category);
    function getTitle() public view returns (bytes32[3] _title);
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash);
    function getFileHash() public view returns (bytes32[2] _fileHash);
    function getBounty() public view returns (uint256);
    function getBalance() public view returns (uint256);
    function getEntryFee() public view returns (uint256);
    function collectMyEntryFee() public;

    function mySubmissions() public view returns (address[]);

    function submissionCount() public view returns (uint256);
    function entrantCount() public view returns (uint256);
    function update(LibConstruction.TournamentModificationData tournamentData) public;

    function selectWinners(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public;
    function editGhostRound(LibConstruction.RoundData _roundData) public;
    function allocateMoreToRound(uint256 _mtxAllocation) public;

    function jumpToNextRound() public;
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress);
    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool _success);
    function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public returns (address _newSubmission);
    function withdrawFromAbandoned() public;
    function recoverFunds() public;

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public;
}
