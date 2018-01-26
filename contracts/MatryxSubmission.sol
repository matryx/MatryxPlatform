pragma solidity ^0.4.18;

import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

contract MatryxSubmission is Ownable, IMatryxSubmission {

	// Parent identification
	address public tournamentAddress;
	address public roundAddress;
	
	// Submission
	string name;
	address author;
	bytes32 externalAddress;
	address[] references;
	address[] contributors;
	uint256 timeSubmitted;
	bool public publicallyAccessibleDuringTournament;

	uint256 balance;

	function MatryxSubmission(address _tournamentAddress, address _roundAddress, address _submissionAuthor, string _name, bytes32 _externalAddress, address[] _references, address[] _contributors, uint256 _timeSubmitted, bool _publicallyAccessibleDuringTournament) public
	{
		require(_submissionAuthor != 0x0);
		

		tournamentAddress = _tournamentAddress;
		roundAddress = _roundAddress;

		name = _name;
		author = _submissionAuthor;
		externalAddress = _externalAddress;
		references = _references;
		contributors = _contributors;
		timeSubmitted = _timeSubmitted;
	}

	/*
	 * Modifiers 
	 */

	 modifier onlyAuthor() {
    	require(msg.sender == author);
    	_;
  	}

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
		IMatryxTournament tournament = IMatryxTournament(tournamentAddress);
		Ownable ownableTournament = Ownable(tournamentAddress);

		bool requesterOwnsTournament = ownableTournament.isOwner(_requester);
		bool requesterOwnsSubmission = _requester == author;
		bool externallyAccessible = publicallyAccessibleDuringTournament;
		bool requesterIsEntrant = IMatryxRound(roundAddress).requesterIsEntrant(_requester);
		bool winningSubmissionChosen = IMatryxRound(roundAddress).submissionChosen();
		bool closedRoundAndEntrantRequesting = (requesterIsEntrant && winningSubmissionChosen);
		bool closedTournamentAndAnyoneRequesting = !tournament.tournamentOpen();

		return requesterOwnsTournament || requesterOwnsSubmission || externallyAccessible || closedTournamentAndAnyoneRequesting || closedRoundAndEntrantRequesting;
	}

	function getName() constant whenAccessible(msg.sender) public returns(string) {
		return name;
	}

	function getAuthor() constant whenAccessible(msg.sender) public returns(address) {
		return author;
	}

	function getExternalAddress() constant whenAccessible(msg.sender) public returns (bytes32)
	{
		return externalAddress;
	}

	function getReferences() constant whenAccessible(msg.sender) public returns(address[]) {
		return references;
	}

	function getContributors() constant whenAccessible(msg.sender) public returns(address[]) {
		return contributors;
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

	function makeExternallyAccessibleDuringTournament() onlyAuthor public
	{
		publicallyAccessibleDuringTournament = true;
	}

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _name New name for the submission.
	function updateName(string _name) onlyAuthor public 
	{
		name = _name;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(bytes32 _externalAddress) onlyAuthor public
	{
		externalAddress = _externalAddress;
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(address _reference) onlyAuthor public 
	{
		references.push(_reference);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _referenceIndex Index of reference to remove.
	function removeReference(uint256 _referenceIndex) onlyAuthor public
	{
		delete references[_referenceIndex];
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(address _contributor) onlyAuthor public
	{
		contributors.push(_contributor);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _contributorIndex) onlyAuthor public 
	{
		delete contributors[_contributorIndex];
	}

	function setBalance(uint256 _bounty) public onlyRound
	{
		balance = _bounty;
	}

	/// @dev Removes a submission from this round (callable only by submission's owner).
    /// @param _submissionIndex Index of the submission to remove.
	// function suicide(uint256 _submissionIndex) onlyAuthor public
	// {
	// 	selfdestruct();
	// }
}