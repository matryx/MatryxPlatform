pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxSubmissionFactory
{
	function createSubmission(address _platformAddress, address _tournamentAddress, address _roundAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}