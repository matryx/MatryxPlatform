pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxTournamentFactory
{
	function createTournament(LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData, address _owner) public returns (address _tournamentAddress);
	function setPlatform(address _platformAddress) public;
}
