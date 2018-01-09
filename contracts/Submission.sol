pragma solidity ^0.4.18;

import './Ownable.sol';
import './Tournament.sol';
import './Round.sol';

contract Submission is Ownable {

	// Tournament identification
	address public tournamentAddress;
	address public roundAddress;
	bool tournamentIsClosed;
	
	// Submission
	string name;
	bytes32[] externalAddress_Versioned;
	address[] references;
	address[] contributors;
	uint256 public timeSubmitted;
	bool public publicallyAccessibleDuringTournament;

	uint256 balance;

	// Submission Constructor
	function Submission(address _tournamentAddress, string _tournamentName, address _submissionAuthor, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, bool _publicallyAccessible) public {
		//Clean inputs
		require(_submissionAuthor != 0x0);
		tournamentAddress = _tournamentAddress;
		roundAddress = msg.sender;
		
		name = _tournamentName;
		owner = _submissionAuthor;
		references = _references;
		contributors = _contributors;
		externalAddress_Versioned.push(_externalAddress);
		timeSubmitted = _timeSubmitted;
		publicallyAccessibleDuringTournament = _publicallyAccessible;
	}

	/*
	 * Modifiers 
	 */

	// A modifier to ensure that information can be obtained
	// about this submission only when it should be (when the creator decides it can
	// or after the tournament has been closed).
	modifier whenAccessible(address _requester)
	{
		require(isAccessible(_requester));
		_;
	}

	modifier onlyRound()
	{
		require(msg.sender == roundAddress);
		_;
	}

	/*
	 * Getters
	 */

	function isAccessible(address _requester) public constant returns (bool)
	{
		Tournament tournament = Tournament(tournamentAddress);

		bool requesterOwnsTournament = tournament.isOwner(_requester);
		bool externallyAccessible = publicallyAccessibleDuringTournament;
		bool requesterIsEntrant = Round(roundAddress).requesterIsEntrant(_requester);
		bool winningSubmissionChosen = Round(roundAddress).submissionChosen();
		bool closedRoundAndContributorRequesting = (requesterIsEntrant && winningSubmissionChosen);
		bool closedTournamentAndAnyoneRequesting = !tournament.tournamentOpen();

		return requesterOwnsTournament || externallyAccessible || closedTournamentAndAnyoneRequesting || closedRoundAndContributorRequesting;
	}

	function getReferences() constant whenAccessible(msg.sender) public returns(address[]) {
		return references;
	}

	function getContributors() constant whenAccessible(msg.sender) public returns(address[]) {
		return contributors;
	}

	function getExternalAddress() constant whenAccessible(msg.sender) public returns(bytes32) {
		uint256 lengthOfSubmissionHistory = externalAddress_Versioned.length;
		return externalAddress_Versioned[lengthOfSubmissionHistory-1];
	}

	function getExternalAddress_FullHistory() constant whenAccessible(msg.sender) public returns (bytes32[])
	{
		return externalAddress_Versioned;
	}

	function getVersionCount() public view returns (uint256)
	{
		return externalAddress_Versioned.length;
	}

	function getTimeSubmitted() constant whenAccessible(msg.sender) public returns(uint256) {
		return timeSubmitted;
	}

	/*
	TODO
	Function - turn the submission into public when the round ends
	Only the tournament
	*/

	/*
	 * Setters
	 */

	function makeExternallyAccessibleDuringTournament() onlyOwner public
	{
		publicallyAccessibleDuringTournament = true;
	}


    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _name New name for the submission.
	function changeName(string _name) onlyOwner public 
	{
		name = _name;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(bytes32 _externalAddress) onlyOwner public
	{
		externalAddress_Versioned.push(_externalAddress);
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) onlyOwner public 
	{
		references.push(_reference);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _referenceIndex Index of reference to remove.
	function removeReference(uint256 _referenceIndex) onlyOwner public
	{
		delete references[_referenceIndex];
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(address _contributor) onlyOwner public
	{
		contributors.push(_contributor);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _contributorIndex) onlyOwner public 
	{
		delete contributors[_contributorIndex];
	}

	function setBalance(uint256 _bounty) public onlyRound
	{
		balance = _bounty;
	}

	/// @dev Removes a submission from this round (callable only by submission's owner).
    /// @param _submissionIndex Index of the submission to remove.
	// function delete(uint256 _submissionIndex) onlyOwner public
	// {
	// 	selfdestruct();
	// }
}