pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";

interface IMatryxPlatform
{
    function invokeTournamentOpenedEvent(bytes32 _tournamentName_1, bytes32 _tournamentName_2, bytes32 _tournamentName_3, bytes32 _externalAddress_1, bytes32 _externalAddress_2, uint256 _MTXReward, uint256 _entryFee) public;
    function invokeTournamentClosedEvent(uint256 _finalRoundNumber, uint256 _MTXReward) public;
    function updateSubmissions(address _owner, address _submission) public;
    function removeSubmission(address _submissionAddress, address _tournamentAddress) public returns (bool);
    function addTournamentToCategory(address _tournamentAddress, bytes32 _category) public;
    function removeTournamentFromCategory(address _tournamentAddress, bytes32 _category) public;
    function updateTournamentCategory(address _tournamentAddress, bytes32 _oldCategory, bytes32 _newCategory) public;
    function getTournamentsByCategory(bytes32 _category) external view returns (address[]);
    function getCategoryCount(bytes32 _category) external view returns (uint256);
    function getTopCategory(uint256 _index) external view returns (bytes32);
    function enterTournament(address _tournamentAddress) public returns (bool _success);
    function createTournament(bytes32 _category, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData) public returns (address _tournamentAddress);
    function enterMatryx() public returns (address);
    function hasEnteredMatryx(address _sender) public view returns (bool);
    function isSubmission(address _submissionAddress) public view returns (bool);
    function isTournament(address _tournamentAddress) public view returns (bool);
    function hashForCategory(bytes32 _categoryHash) public view returns (bytes32 _category);
    function getTournament_IsMine(address _tournamentAddress) public view returns (bool _isMine);
    function setSubmissionGratitude(uint256 _gratitude) public;
    function getTokenAddress() public view returns (address);
    function getTournamentFactoryAddress() public view returns (address);
    function getSubmissionGratitude() public view returns (uint256);
    function myTournaments() public view returns (address[]);
    function mySubmissions() public view returns (address[]);
    function tournamentCount() public view returns (uint256 _tournamentCount);
    function getTournamentAtIndex(uint256 _index) public view returns (address _tournamentAddress);
}
