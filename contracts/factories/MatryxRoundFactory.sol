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

	function createRound(address _platformAddress, address _tournamentAddress, address _owner, LibConstruction.RoundData roundData) public returns (address _roundAddress) {
		LibConstruction.RequiredRoundAddresses memory requiredAddresses = LibConstruction.RequiredRoundAddresses({platformAddress: _platformAddress, matryxTokenAddress: matryxTokenAddress, tournamentAddress: _tournamentAddress, submissionFactoryAddress: matryxSubmissionFactoryAddress});
		MatryxRound newRound = new MatryxRound(requiredAddresses, _owner, roundData);
		return newRound;
	}
}