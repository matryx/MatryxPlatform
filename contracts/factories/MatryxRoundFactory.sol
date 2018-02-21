pragma solidity ^0.4.18;

import '../MatryxRound.sol';

contract MatryxRoundFactory {
	address public matryxSubmissionFactoryAddress;
	address public matryxTokenAddress;

	function MatryxRoundFactory(address _matryxTokenAddress, address _matryxSubmissionFactoryAddress) public {
		matryxTokenAddress = _matryxTokenAddress;
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
	}

	function createRound(address _platformAddress, address _tournamentAddress, address _owner, uint256 _bountyMTX) public returns (address _roundAddress) {
		MatryxRound newRound = new MatryxRound(matryxTokenAddress, _platformAddress, _tournamentAddress, matryxSubmissionFactoryAddress, _owner, _bountyMTX);
		return newRound;
	}
}