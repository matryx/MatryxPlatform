pragma solidity ^0.4.18;

import '../MatryxSubmission.sol';

contract MatryxSubmissionFactory {

	function createSubmission(address _tournamentAddress, address _roundAddress, address _submissionAuthor, string _name, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, bool _publicallyAccessibleDuringTournament) public returns (address _submissionAddress) {
		MatryxSubmission submission = new MatryxSubmission(_tournamentAddress, _roundAddress, _submissionAuthor, _name, _externalAddress, _references, _contributors, _timeSubmitted, _publicallyAccessibleDuringTournament);
		return submission;
	}
}