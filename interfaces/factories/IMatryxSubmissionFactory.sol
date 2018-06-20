pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxSubmissionFactory
{
	function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.RequiredSubmissionAddresses requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}