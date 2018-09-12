pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";

interface IMatryxRound
{
    function submissionExists(address _submissionAddress) public view returns (bool);
    function addBounty(uint256 _mtxAllocation) public;
    function getState() public view returns (uint256);
    function getPlatform() public view returns (address);
    function getTournament() public view returns (address);
    function getData() public view returns (LibConstruction.RoundData _roundData);
    function getStartTime() public view returns (uint256);
    function getEndTime() public view returns (uint256);
    function getReviewPeriodDuration() public view returns (uint256);
    function getBounty() public view returns (uint256);
    function getRemainingBounty() public view returns (uint256);
    function getTokenAddress() public view returns (address);
    function getSubmissions() public view returns (address[] _submissions);
    function getBalance(address _submissionAddress) public view returns (uint256);
    function getRoundBalance() public view returns (uint256);
    function submissionsChosen() public view returns (bool);
    function getWinningSubmissionAddresses() public view returns (address[]);
    function numberOfSubmissions() public view returns (uint256);
    function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public;
    function transferToTournament(uint256 _amount) public;
    function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public;
    function transferBountyToTournament() public returns (uint256);
    function transferAllToWinners(uint256 _tournamentBalance) public;
    function startNow() public;
    function createSubmission(address _owner, address platformAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}
