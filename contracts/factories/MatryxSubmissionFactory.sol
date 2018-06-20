pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import '../MatryxSubmission.sol';

contract MatryxSubmissionFactory {

	function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, LibConstruction.RequiredSubmissionAddresses requiredAddresses, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress) {
		return new MatryxSubmission(_contributors, _contributorRewardDistribution, _references, requiredAddresses, submissionData);
	}
}