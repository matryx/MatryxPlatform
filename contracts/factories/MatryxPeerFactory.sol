pragma solidity ^0.4.18;

import '../MatryxPeer.sol';
import '../../libraries/math/SafeMath128.sol';

contract MatryxPeerFactory is Ownable {
	using SafeMath128 for uint128;

	address public platformAddress;
	uint64 public peerCount;

	function setPlatform(address _platformAddress) public onlyOwner
	{
		platformAddress = _platformAddress;
	}

	function createPeer(address _owner) public returns (address _peerAddress) {
		uint128 trust = getTrustForNewPeer();
		MatryxPeer peerAddress = new MatryxPeer(platformAddress, _owner, trust);
		peerCount  = uint64(uint128(peerCount).add(1));
		return peerAddress;
	}

	function getTrustForNewPeer() public constant returns (uint128)
	{
		uint128 integralTopValue = fastSigmoid(peerCount+2);
		uint128 integralBottomValue = fastSigmoid(peerCount+1);
		uint128 trustValue = integralTopValue - integralBottomValue;
		require(trustValue >= 0);

		return trustValue;
	}

	function fastSigmoid(uint256 _input) public pure returns (uint128)
	{
		uint128 one = 1 * 10**18;
		uint128 two = 2 * 10**18;
		uint128 inputWithDecimals = uint128(_input) * 10**18;

		return (two.mul(inputWithDecimals)).div(one.add(inputWithDecimals));
	}
}