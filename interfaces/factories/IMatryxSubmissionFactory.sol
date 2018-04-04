pragma solidity ^0.4.18;

interface IMatryxSubmissionFactory
{
	function createSubmission(address platformAddress, address tournamentAddress, address roundAddress, string title, address owner, address author, bytes externalAddress, address[] references, address[] contributors, uint128[] contributorRewardDistribution) public returns (address _submissionAddress);
}