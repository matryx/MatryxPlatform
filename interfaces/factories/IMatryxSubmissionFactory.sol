pragma solidity ^0.4.18;

interface IMatryxSubmissionFactory
{
	function createSubmission(address tournamentAddress, address roundAddress, string title, address author, bytes32 externalAddress, address[] references, address[] contributors, uint256 timeSubmitted, bool publicallyAccessibleDuringTournament) public returns (address _submissionAddress);
}