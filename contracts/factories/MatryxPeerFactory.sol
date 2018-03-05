pragma solidity ^0.4.18;

import '../MatryxPeer.sol';
import '../../libraries/math/SafeMath.sol';

contract MatryxPeerFactory is Ownable {
	using SafeMath for uint256;

	address public platformAddress;
	uint256 public peerCount;

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}

	function createPeer(address _owner) public returns (address _peerAddress) {
		uint256 trust = getTrustForNewPeer();
		MatryxPeer peerAddress = new MatryxPeer(platformAddress, _owner, trust);
		peerCount  = peerCount.add(1);
		return peerAddress;
	}

	function getTrustForNewPeer() internal constant returns (uint256)
	{
		uint256 integralTopValue = fastSigmoid(peerCount+2);
		uint256 integralBottomValue = fastSigmoid(peerCount+1);
		uint trustValue = integralTopValue - integralBottomValue;
		require(trustValue >= 0);

		return trustValue;
	}

	function fastSigmoid(uint256 _input) internal pure returns (uint256)
	{
		uint256 one = 1 * 10**18;
		uint256 two = 2 * 10**18;
		uint256 inputWithDecimals = _input * 10**18;

		return (two.mul(_input)).div(one.add(inputWithDecimals));
	}
}