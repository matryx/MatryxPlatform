pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import '../MatryxTournament.sol';
import '../Ownable.sol';

contract MatryxTournamentFactory is Ownable {
	address public matryxTokenAddress;
	address public platformAddress;
	address public matryxRoundFactoryAddress;

	function MatryxTournamentFactory(address _matryxTokenAddress, address _matryxRoundFactoryAddress) public {
		matryxTokenAddress = _matryxTokenAddress;
		matryxRoundFactoryAddress = _matryxRoundFactoryAddress;
	}

	function createTournament(LibConstruction.TournamentData memory tournamentData, LibConstruction.RoundData memory roundData, address _owner) returns (address _tournamentAddress) {
		MatryxTournament newTournament = new MatryxTournament(tournamentData, roundData, platformAddress, matryxTokenAddress, matryxRoundFactoryAddress, _owner);
		return newTournament;
	}

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}
}