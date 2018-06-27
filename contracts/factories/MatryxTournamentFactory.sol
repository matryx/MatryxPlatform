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

	function createTournament(string _category, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData, address _owner) returns (address _tournamentAddress) {
		MatryxTournament newTournament = new MatryxTournament(_category, tournamentData, roundData, platformAddress, matryxTokenAddress, matryxRoundFactoryAddress, _owner);
		return newTournament;
	}

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}
}