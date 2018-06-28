pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import '../MatryxRound.sol';
import "../../libraries/LibConstruction.sol";

contract MatryxRoundFactory {
	address public matryxSubmissionFactoryAddress;
	address public matryxTokenAddress;

	function MatryxRoundFactory(address _matryxTokenAddress, address _matryxSubmissionFactoryAddress) public {
		matryxTokenAddress = _matryxTokenAddress;
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
	}

	function createRound(address _platformAddress, address _tournamentAddress, address _owner, uint256 _roundIndex, LibConstruction.RoundData roundData) public returns (address _roundAddress) {
		MatryxRound newRound = new MatryxRound(_platformAddress, matryxTokenAddress, _tournamentAddress, matryxSubmissionFactoryAddress, _owner, _roundIndex, roundData);
		return newRound;
	}
}