pragma solidity ^0.4.18;

import '../MatryxRound.sol';

contract MatryxRoundFactory {
	address public matryxSubmissionFactoryAddress;

	function MatryxRoundFactory(address _matryxSubmissionFactoryAddress) public {
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
	}

	function createRound(address _tournamentAddress, uint256 _bountyMTX) public returns (address _roundAddress) {
		MatryxRound newRound = new MatryxRound(_tournamentAddress, matryxSubmissionFactoryAddress, _bountyMTX);
		return newRound;
	}
}