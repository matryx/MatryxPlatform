pragma solidity ^0.4.11;

///Creating a tournament and the functionality
contract Submission {

	//Variables involved in a Submission
	address public TournamentOwner;
	address public TournamentAddress;
	string Name;
	address public SubmissionOwner;
	string Title;
	string IpfsHash;
	uint256 public TimeSubmitted;
	uint256 public RoundEndTime;


//TODO build the interaction methods
/*
get

Function - turn the submission into public when the round ends
Only the tournament


*/
	function Submission(address tournamentOwner, address tournamentAddress, string name, address submissionOwner, string title,
	 						string ipfsHash, uint256 timeSubmitted, uint256 roundEndTime)
	{
		//Clean inputs
		require(timeSubmitted >= now);
		require(title != "");
		require(roundEndTime >= timeSubmitted);
		require(submissionOwner != 0x0);
		require(_token != 0x0);

		TournamentOwner = tournamentOwner;
		TournamentAddress = tournamentAddress;
		Name = name; 
		SubmissionOwner = submissionOwner;
		Title = title;
		IpfsHash = ipfsHash;
		TimeSubmitted = TimeSubmitted;
		RoundEndTime = roundEndTime;

	}

}