pragma solidity ^0.4.18;


import './Ownable.sol';

// Allows a user to easily view all tournaments
contract SubmissionViewer is Ownable{

	// An event to be fired at the end of every round,
	// one time per submission that was created in that round
	event SubmissionCreated(string name, bytes32 externalAddress, address[] references, address[] contributors, uint256 timeSubmitted, address submissionOwner);

	// Allows another contract to call the SubmissionCreated event
	function CallSubmissionCreatedEvent(string _name, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, address _submissionOwner) public onlyOwner
	{
		SubmissionCreated(_name, _externalAddress, _references, _contributors, _timeSubmitted, _submissionOwner);
	}
}