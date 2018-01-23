pragma solidity ^0.4.18;

import '../MatryxRound.sol';

contract MatryxRoundFactory {
	address public matryxSubmissionFactoryAddress;

	function MatryxRoundFactory(address _matryxSubmissionFactoryAddress) public {
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
	}

	function createRound(uint256 _bountyMTX) public returns (address _roundAddress) {
		MatryxRound newRound = new MatryxRound(matryxSubmissionFactoryAddress, _bountyMTX);
		return newRound;
	}
}