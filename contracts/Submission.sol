pragma solidity ^0.4.18;


import './Ownable.sol';
import './Tournament.sol';

///Creating a submission and the functionality
contract Submission is Ownable {

	// Tournament identification
	address public tournamentAddress;
	address public tournamentOwner;
	bool tournamentIsClosed;
	
	// Submission
	string name;
	address[] references;
	address[] contributors;
	bytes32 externalAddress;
	uint256 public timeSubmitted;
	uint256 private roundEndTime;
	bool externallyAccessibleDuringTournament;

	// Submission Constructor
	function Submission(address _tournamentAddress, address _tournamentOwner, address _submissionOwner, string _name, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, uint256 _roundEndTime) public {
		//Clean inputs
		require(_submissionOwner != 0x0);
		tournamentAddress = _tournamentAddress;
		tournamentOwner = _tournamentOwner;
		name = _name;
		owner = _submissionOwner;
		references = _references;
		contributors = _contributors;
		externalAddress = _externalAddress;
		timeSubmitted = _timeSubmitted;
		roundEndTime = _roundEndTime;
	}

	// ----------------- Modifiers -----------------

	// A modifier to ensure that information can be obtained
	// about this submission only when it should be (when the creator decides it can
	// or after the tournament has been closed).
	modifier whenAccessible(address _requester)
	{
		require(isAccessible(_requester));
		_;
	}

	// ----------------- Accessor Methods -----------------

	function isAccessible(address _requester) public constant returns (bool)
	{
		// NEEDS WORK.
		// TODO: Figure out who should set tournamentIsClosed
		// TODO: Figure out how to make this work for multiple rounds.
		// TODO: Figure out how to make this submission inaccessible to tournament entrants
		// when the round this was created in is the current round
		// (this submission should be visible to those in the tournament if
		// it was created last round, two rounds ago, etc.)
		Tournament tournament = Tournament(tournamentAddress);
		bool senderOwnsTournament = tournament.isOwner(_requester);
		//bool externallyAccessible = externallyAccessibleDuringTournament;
		// TODO: Think about this next part carefully.
		// Who is responsible for tournamentIsClosed? This submission? The tournament?
		// How often are users going to call the accessors of a submission? And on the other hand...
		// How expensive would it be for the tournament owner to update all submissions?

		// tl;dr Who should pay what gas:
		//    1) tournament creator a lot, but only once? 
		//    2) submission creators a little, but potentially many times?
		//    3) both??
		bool closedTournament = !tournament.tournamentOpen();

		return senderOwnsTournament || externallyAccessibleDuringTournament || closedTournament;
	}

	function getSubmissionOwner() constant whenAccessible(msg.sender) public returns (address) {
		return owner;
	}

	function getReferences() constant whenAccessible(msg.sender) public returns(address[]) {
		return references;
	}

	function getContributors() constant whenAccessible(msg.sender) public returns(address[]) {
		return contributors;
	}

	function getExternalAddress() constant whenAccessible(msg.sender) public returns(bytes32) {
		return externalAddress;
	}

	function getTimeSubmitted() constant whenAccessible(msg.sender) public returns(uint256) {
		return timeSubmitted;
	}

	/*
	TODO
	Function - turn the submission into public when the round ends
	Only the tournament
	*/

	//TODO setters with correct scoping

	function makeExternallyAccessibleDuringTournament() onlyOwner public
	{
		externallyAccessibleDuringTournament = true;
	}
}