pragma solidity ^0.4.18;

import './Ownable.sol';
import './Tournament.sol';
import './Round.sol';

library Submission {

	struct MatryxSubmission
	{
		// Tournament identification
		address tournamentAddress;
		address roundAddress;
		
		// Submission
		string name;
		address author;
		bytes32 externalAddress;
		address[] references;
		address[] contributors;
		uint256 timeSubmitted;
		bool publicallyAccessibleDuringTournament;

		uint256 balance;
	}
	/*
	 * Modifiers 
	 */

	 modifier onlyAuthor(MatryxSubmission storage self) {
    	require(msg.sender == self.author);
    	_;
  	}

	// A modifier to ensure that information can be obtained
	// about this submission only when it should be (when the creator decides it can
	// or after the tournament has been closed).
	modifier whenAccessible(MatryxSubmission storage self, address _requester)
	{
		require(isAccessible(self, _requester));
		_;
	}

	modifier onlyRound(MatryxSubmission storage self)
	{
		require(msg.sender == self.roundAddress);
		_;
	}

	/*
	 * Getters
	 */

	function isAccessible(MatryxSubmission storage self, address _requester) public constant returns (bool)
	{
		Tournament tournament = Tournament(self.tournamentAddress);

		bool requesterOwnsTournament = tournament.isOwner(_requester);
		bool requesterOwnsSubmission = _requester == self.author;
		bool externallyAccessible = self.publicallyAccessibleDuringTournament;
		bool requesterIsEntrant = Round(self.roundAddress).requesterIsEntrant(_requester);
		bool winningSubmissionChosen = Round(self.roundAddress).submissionChosen();
		bool closedRoundAndEntrantRequesting = (requesterIsEntrant && winningSubmissionChosen);
		bool closedTournamentAndAnyoneRequesting = !tournament.tournamentOpen();

		return requesterOwnsTournament || requesterOwnsSubmission || externallyAccessible || closedTournamentAndAnyoneRequesting || closedRoundAndEntrantRequesting;
	}

	function getReferences(MatryxSubmission storage self) constant whenAccessible(self, msg.sender) public returns(address[]) {
		return self.references;
	}

	function getContributors(MatryxSubmission storage self) constant whenAccessible(self, msg.sender) public returns(address[]) {
		return self.contributors;
	}

	function getExternalAddress(MatryxSubmission storage self) constant whenAccessible(self, msg.sender) public returns (bytes32)
	{
		return self.externalAddress;
	}

	function getVersionCount(MatryxSubmission storage self) public view returns (uint256)
	{
		return self.externalAddress.length;
	}

	function getTimeSubmitted(MatryxSubmission storage self) constant whenAccessible(self, msg.sender) public returns(uint256) {
		return self.timeSubmitted;
	}

	/*
	TODO
	Function - turn the submission into public when the round ends
	Only the tournament
	*/

	/*
	 * Setters
	 */

	function makeExternallyAccessibleDuringTournament(MatryxSubmission storage self) onlyAuthor(self) public
	{
		self.publicallyAccessibleDuringTournament = true;
	}

    /// @dev Edit the title of a submission (callable only by submission's owner).
    /// @param _name New name for the submission.
	function updateName(MatryxSubmission storage self, string _name) onlyAuthor(self) public 
	{
		self.name = _name;
	}

	/// @dev Update the external address of a submission (callable only by submission's owner).
    /// @param _externalAddress New content hash for the body of the submission.
	function updateExternalAddress(MatryxSubmission storage self, bytes32 _externalAddress) onlyAuthor(self) public
	{
		self.externalAddress = _externalAddress;
	}

	/// @dev Add a missing reference to a submission (callable only by submission's owner).
    /// @param _reference Address of additional reference to include.
	function addReference(MatryxSubmission storage self, address _reference) onlyAuthor(self) public 
	{
		self.references.push(_reference);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's owner).
    /// @param _referenceIndex Index of reference to remove.
	function removeReference(MatryxSubmission storage self, uint256 _referenceIndex) onlyAuthor(self) public
	{
		delete self.references[_referenceIndex];
	}

	/// @dev Add a contributor to a submission (callable only by submission's owner).
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(MatryxSubmission storage self, address _contributor) onlyAuthor(self) public
	{
		self.contributors.push(_contributor);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's owner).
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(MatryxSubmission storage self, uint256 _contributorIndex) onlyAuthor(self) public 
	{
		delete self.contributors[_contributorIndex];
	}

	function setBalance(MatryxSubmission storage self, uint256 _bounty) public onlyRound(self)
	{
		self.balance = _bounty;
	}

	/// @dev Removes a submission from this round (callable only by submission's owner).
    /// @param _submissionIndex Index of the submission to remove.
	// function delete(uint256 _submissionIndex) onlyAuthor public
	// {
	// 	selfdestruct();
	// }
}