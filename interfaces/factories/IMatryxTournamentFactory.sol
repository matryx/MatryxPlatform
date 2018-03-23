pragma solidity ^0.4.18;

interface IMatryxTournamentFactory
{
	function createTournament(address _owner, string _tournamentTitle, bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee, uint256 _reviewPeriod) public returns (address _tournamentAddress);
	function setPlatform(address _platformAddress) public;
}