pragma solidity ^0.4.18;

import '../MatryxTournament.sol';
import '../Ownable.sol';

contract MatryxTournamentFactory is Ownable {
	address public matryxRoundFactoryAddress;
	address public platformAddress;

	function MatryxTournamentFactory(address _matryxRoundFactoryAddress) public {
		matryxRoundFactoryAddress = _matryxRoundFactoryAddress;
	}

	function createTournament(address _owner, string _tournamentName, bytes32 _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public returns (address _roundAddress) {
		MatryxTournament newTournament = new MatryxTournament(platformAddress, this, _owner, _tournamentName, _externalAddress, _BountyMTX, _entryFee);
		return newTournament;
	}

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}
}