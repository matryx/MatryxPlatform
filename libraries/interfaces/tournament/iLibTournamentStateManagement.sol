pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

interface iLibTournamentStateManagement
{
    function getState(address[] storage rounds) public view returns (uint256 _state);
    function currentRound(address[] storage rounds) public view returns (uint256 _currentRound, address _currentRoundAddress);
    function getGhostRound(address[] storage rounds) internal returns (uint256 _index, address _ghostAddress);
}