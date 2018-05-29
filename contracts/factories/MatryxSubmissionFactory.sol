pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import '../MatryxSubmission.sol';

contract MatryxSubmissionFactory {

	function createSubmission(address _platformAddress, address _tournamentAddress, address _roundAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress) {
		return new MatryxSubmission(_platformAddress, _tournamentAddress, _roundAddress, submissionData);
	}
}