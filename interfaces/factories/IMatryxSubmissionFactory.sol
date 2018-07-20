pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxSubmissionFactory
{
	// function createSubmission(address[3] requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
	function createSubmission(address _owner, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}
