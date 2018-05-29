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

	function createTournament(address _owner, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData) public returns (address _tournamentAddress) {
		LibConstruction.RequiredTournamentAddresses memory addresses = LibConstruction.RequiredTournamentAddresses({platformAddress: platformAddress, matryxTokenAddress: matryxTokenAddress, roundFactoryAddress: matryxRoundFactoryAddress});
		MatryxTournament newTournament = new MatryxTournament(addresses, _owner, tournamentData, roundData);
		return newTournament;
	}

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}
}