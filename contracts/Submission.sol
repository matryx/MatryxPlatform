pragma solidity ^0.4.11;


import './Ownable.sol';

///Creating a submission and the functionality
contract Submission is Ownable {

	//Variables involved in a Submission
	address public tournamentOwner;
	address public tournamentAddress;
	address public submissionOwner;
	string title;
	string body; //placeholder for description or something
	string references;
	string contributors;
	string ipfsHash;
	uint256 public timeSubmitted;
	uint256 public roundEndTime;


	function getTournamentOwner() constant public returns(address){
		return tournamentOwner;
	}

	function getTournamentAddress() constant public returns(address){
		return tournamentAddress;
	}

	function getSubmissionOwner() constant public returns (address){
		return submissionOwner;
	}

	function getTitle() constant public returns (string){
		return title;
	}

// Make this Ownable after testing 
	function getBody() constant returns(string){
		return body;
	}

	function getReferences() constant public returns(string){
		return references;
	}

	function getContributors() constant public returns(string){
		return contributors;
	}

	function getIpfsHash() constant public returns(string){
		return ipfsHash;
	}

	function getTimeSubmitted() constant public returns(uint256){
		return timeSubmitted;
	}

	function getRoundEndTime() constant public returns(uint256){
		return roundEndTime;
	}


	//TODO setters with correct scoping


/*
TODO
Function - turn the submission into public when the round ends
Only the tournament
*/
function Submission(address _tournamentOwner, address _tournamentAddress, address _submissionOwner, string _title, string _body, string _references, string _contributors, 
	string _ipfsHash, uint256 _timeSubmitted, uint256 _roundEndTime){
	//Clean inputs
	require(_timeSubmitted >= now);
	require(_roundEndTime >= _timeSubmitted);
	require(_submissionOwner != 0x0);

	tournamentOwner = _tournamentOwner;
	tournamentAddress = _tournamentAddress;
	submissionOwner = _submissionOwner;
	title = _title;
	body = _body;
	references = _references;
	contributors = _contributors;
	ipfsHash = _ipfsHash;
	timeSubmitted = _timeSubmitted;
	roundEndTime = _roundEndTime;

}

}