pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxSubmissionFactory
{
	// function createSubmission(address _owner, address[3] _requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
	function createSubmission(address _owner, address platformAddress, address tournamentAddress, address roundAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}
