pragma solidity ^0.4.18;

interface IMatryxTournamentFactory
{
	function createTournament(address _owner, string _category, string _tournamentTitle, bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee) public returns (address _tournamentAddress);
	function setPlatform(address _platformAddress) public;
}