pragma solidity ^0.4.18;

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

	function createTournament(address _owner, string _category, string _tournamentTitle, bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public returns (address _tournamentAddress) {
		MatryxTournament newTournament = new MatryxTournament(platformAddress, matryxTokenAddress, matryxRoundFactoryAddress, _owner, _category, _tournamentTitle, _externalAddress, _BountyMTX, _entryFee);
		return newTournament;
	}

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}
}