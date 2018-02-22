pragma solidity ^0.4.18;

interface IMatryxPeerFactory
{
	function setPlatform(address _platformAddress) public;
	function createPeer(address _owner) public returns (address _peerAddress);
}