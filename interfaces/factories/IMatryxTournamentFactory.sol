pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxTournamentFactory
{
	function createTournament(LibConstruction.TournamentData memory tournamentData, LibConstruction.RoundData memory roundData, address _owner) returns (address _tournamentAddress);
	function setPlatform(address _platformAddress) public;
}