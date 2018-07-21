pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";

interface IMatryxRound
{
    //function removeSubmission(address _submissionAddress) public returns (bool);
    function submissionExists(address _submissionAddress) public returns (bool);
    function addBounty(uint256 _mtxAllocation) public;
    function getState() public view returns (uint256);
	function getTournament() public view returns (address);
    function getStartTime() public view returns (uint256);
    function getEndTime() public view returns (uint256);
    function getBounty() public view returns (uint256);
    function getTokenAddress() public view returns (address);
    function getSubmissions() public view returns (address[] _submissions);
    function getBalance(address _submissionAddress) public view returns (uint256);
    function submissionsChosen() public view returns (bool);
    function getWinningSubmissionAddresses() public view returns (address[]);
    function numberOfSubmissions() public view returns (uint256);
    function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public;
    function transferToTournament(uint256 _amount) public;
    function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public;
    function transferAllToWinners(uint256 _tournamentBalance) public;
    function startNow() public;
    function closeRound() public;
    //function awardBounty(address _submissionAddress, uint256 _remainingBounty) public;
    function createSubmission(address _owner, address _platformAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
    function transferBountyToTournament() public returns (uint256);
}
