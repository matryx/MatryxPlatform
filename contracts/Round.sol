pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './Ownable.sol';
import './Tournament.sol';
import './MatryxToken.sol';

/// @title Round - A round within a Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract Round is Ownable {
	using SafeMath for uint256;

	//TODO: time restriction on review period
	//TODO: allow for refunds
	address public tournamentAddress;
	address public matryxToken;
	uint256 public roundIndex;
	address public previousRound;
	address public nextRound;
	uint256 public startTime;
	uint256 public endTime;
	uint256 public reviewPeriodEndTime;
	uint256 public reward;
	uint256 public winningSubmissionIndex;
	bool public winningSubmissionChosen;

	mapping(address => uint) addressToParticipantType;
 	mapping(address => Submission[]) contributorToSubmissionArray;
	mapping(bytes32 => Submission) externalAddressToSubmission;
	Submission[] submissions;


	function Round(address _tournamentAddress, uint256 _reward, uint256 _roundIndex) public
	{		
		tournamentAddress = _tournamentAddress;
		roundIndex = _roundIndex;
		reward = _reward;
		winningSubmissionChosen = false;
	}

	struct Submission
	{
		// Tournament identification
		address tournamentAddress;
		
		// Submission
		string name;
		address author;
		bytes32[] externalAddress_Versioned;
		address[] references;
		address[] contributors;
		uint256 timeSubmitted;
		bool publicallyAccessibleDuringTournament;

		uint256 balance;
	}

    /*
     * Enums
     */

	enum participantType { nonentrant, entrant, contributor, author }

	/*
     * Events
     */

	event WinningSubmissionChosen(uint256 _submissionIndex);

	/*
     * Modifiers
     */

    /// @dev Requires that this round is in the open submission state.
	modifier duringOpenSubmission()
	{
		require(now > startTime);
		require(endTime > now);
		require(winningSubmissionChosen == false);
		_;
	}

	/// @dev Requires that this round is in the winner selection state.
	modifier duringWinnerSelection()
	{
		require(endTime != 0);
		require(now > endTime);
		require(winningSubmissionChosen == false);
		_;
	}

	/// @dev Requires that a winner has been selected for this round.
	modifier afterWinnerSelected()
	{
		require(winningSubmissionChosen == true);
		_;
	}

	/// @dev Requires that this round's tournament is open.
	modifier whileTournamentOpen()
	{
		Tournament tournament = Tournament(tournamentAddress);
		require(tournament.tournamentOpen());
		_;
	}

	/// @dev Requires that the desired submission is accessible to the requester.
	modifier whenAccessible(address _requester, uint256 _index)
	{
		require(submissionIsAccessible(_requester, _index));
		_;
	}

	/// @dev Requires that the sender be the submission's author.
	modifier onlySubmissionAuthor(uint256 _submissionIndex)
	{
		require(submissions[_submissionIndex].author == msg.sender);
		_;
	}

	/*
     * Access Control Methods
     */

     /// @dev Returns whether or not this round is open to new submissions.
     /// @return Whether or not this round is open to submissions.
    function roundIsOpen() public constant returns (bool)
	{
		return (now > startTime) && (endTime > now) && (winningSubmissionChosen == false);
	}

	/// @dev Returns whether or not the submission is accessible to the requester.
	/// @param _requester Address requesting the submission
	/// @param _index Index of the submission being requested.
    /// @return Whether or not the submission is accessible to the requester.
	function submissionIsAccessible(address _requester, uint256 _index) public constant returns (bool)
	{
		Tournament tournament = Tournament(tournamentAddress);
		Submission memory submission = submissions[_index];

		bool requesterOwnsTournament = tournament.isOwner(_requester);
		bool requesterIsEntrant = addressToParticipantType[_requester] != 0;
		bool publicallyAccessible = submission.publicallyAccessibleDuringTournament;
		bool closedTournament = !tournament.tournamentOpen();

		return requesterOwnsTournament || publicallyAccessible || closedTournament || (requesterIsEntrant && winningSubmissionChosen);
	}

	/*
     * Getter Methods
     */

	/// @dev Returns all submissions made to this round.
	/// @return _submissions All submissions made to this round.
	function getSubmissions() public constant returns (Submission[] _submissions)
	{
		return submissions;
	}

	/// @dev Returns the contents of a submission.
	/// @param _index Index of the requested submission.
	/// @return _name Name of the submission.
	/// @return _author Author of the submission.
	/// @return _externalAddress Off-chain content hash of submission details (ipfs hash).
	/// @return _references Addresses of submissions referenced in creating this submission
    /// @return _contributors Contributors to this submission.
	/// @return _timeSubmitted Epoch time this this submission was made.
	function getSubmission(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (string _name, address _author, bytes32 _externalAddress, address[] _references, address[] contributors, uint256 _timeSubmitted)
	{
		Submission memory submission = submissions[_index];
		uint256 externalAddressHistoryLength = submission.externalAddress_Versioned.length;
		return (submission.name, submission.author, submission.externalAddress_Versioned[externalAddressHistoryLength-1], submission.references, submission.contributors, submission.timeSubmitted);
	}

	/// @dev Returns the author of a submission.
	/// @param _index Index of the submission.
	/// @return Address of this submission's author.
	function getSubmissionAuthor(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (address) 
	{
		return submissions[_index].author;
	}

	/// @dev Returns a list of submissions referenced by this submission.
	/// @param _index Index of the submission.
	/// @return Addresses of submissions referenced by this submission.
	function getSubmissionReferences(uint256 _index) public constant whenAccessible(msg.sender, _index) returns(address[])
	{
		return submissions[_index].references;
	}

	/// @dev Returns a list of a contributors for a submission.
	/// @param _index Index of the submission.
	/// @return Addresses of contributors.
	function getSubmissionContributors(uint256 _index) public constant whenAccessible(msg.sender, _index) returns(address[])
	{
		return submissions[_index].contributors;
	}

	/// @dev Returns the latest off-chain content hash for this submission (an ipfs hash).
	/// @param _index Index of the submission.
	/// @return Content hash of the body of the submission.
	function getSubmissionExternalAddress(uint256 _index) public constant whenAccessible(msg.sender, _index) returns(bytes32)
	{
		Submission memory submission = submissions[_index];
		uint256 lengthOfSubmissionHistory = submission.externalAddress_Versioned.length;
		return submission.externalAddress_Versioned[lengthOfSubmissionHistory-1];
	}

	/// @dev Returns all off-chain content hashes this submission has listed.
	/// @param _index Index of the submission.
	/// @return List of content hashes of the body of the submission.
	function getSubmissionExternalAddress_History(uint _index) public constant whenAccessible(msg.sender, _index) returns (bytes32[])
	{
		return submissions[_index].externalAddress_Versioned;
	}

	/// @dev Returns the time this submission was made.
	/// @param _index Index of the submission.
	/// @return Epoch time this this submission was made.
	function getSubmissionTimeSubmitted(uint256 _index) public constant whenAccessible(msg.sender, _index) returns(uint256)
	{
		return submissions[_index].timeSubmitted;
	}

	/// @dev Returns the index of this round's winning submission.
	/// @return Index of the winning submission.
	function getWinningSubmissionIndex() public constant returns (uint256)
	{
		return winningSubmissionIndex;
	}

	/// @dev Returns the number of submissions made to this round.
	/// @return Number of submissions made to this round.
	function numberOfSubmissions() public constant returns (uint256)
	{
		return submissions.length;
	}

	/*
     * Setter Methods
     */

    /// @dev Edit the title of a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to edit.
    /// @param _name New name for the submission.
	function editSubmissionName(uint256 _submissionIndex, string _name) onlySubmissionAuthor(_submissionIndex) public 
	{
		submissions[_submissionIndex].name = _name;
	}

	/// @dev Update the external address of a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to update.
    /// @param _externalAddress New content hash for the body of the submission.
	function editSubmissionExternalAddress(uint256 _submissionIndex, bytes32 _externalAddress) onlySubmissionAuthor(_submissionIndex) public
	{
		submissions[_submissionIndex].externalAddress_Versioned.push(_externalAddress);
	}

	/// @dev Add a missing reference to a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to update.
    /// @param _reference Address of additional reference to include.
	function addReference(uint256 _submissionIndex, address _reference) onlySubmissionAuthor(_submissionIndex) public 
	{
		submissions[_submissionIndex].references.push(_reference);
	}

	/// @dev Remove an erroneous reference to a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to update.
    /// @param _referenceIndex Index of reference to remove.
	function removeReference(uint256 _submissionIndex, uint256 _referenceIndex) onlySubmissionAuthor(_submissionIndex) public
	{
		delete submissions[_submissionIndex].references[_referenceIndex];
	}

	/// @dev Add a contributor to a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to update.
    /// @param _contributor Address of contributor to add to the submission.
	function addContributor(uint256 _submissionIndex, address _contributor) onlySubmissionAuthor(_submissionIndex) public
	{
		submissions[_submissionIndex].contributors.push(_contributor);
	}

	/// @dev Remove a contributor from a submission (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to update.
    /// @param _contributorIndex Index of the contributor to remove from the submission.
	function removeContributor(uint256 _submissionIndex, uint256 _contributorIndex) onlySubmissionAuthor(_submissionIndex) public 
	{
		delete submissions[_submissionIndex].contributors[_contributorIndex];
	}

	/// @dev Removes a submission from this round (callable only by submission's author).
    /// @param _submissionIndex Index of the submission to remove.
	function removeSubmission(uint256 _submissionIndex) onlySubmissionAuthor(_submissionIndex) public
	{
		delete submissions[_submissionIndex];
	}

	/*
     * Round Admin Methods
     */

    /// @dev Starts the round (callable only by the owner of the round).
    /// @param _duration Duration of the round in seconds.
	function Start(uint256 _duration) public onlyOwner
	{
		startTime = now;
		endTime = startTime.add(_duration);
	}

	/// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _submissionIndex Index of the winning submission.
	function chooseWinningSubmission(uint256 _submissionIndex) public onlyOwner duringWinnerSelection
	{
		//TODO: apply time restrictions.
		winningSubmissionIndex = _submissionIndex;
		submissions[winningSubmissionIndex].balance.add(reward);
		WinningSubmissionChosen(winningSubmissionIndex);
		
		reward = 0;
		winningSubmissionChosen = true;
	}

	/*
     * Entrant Methods
     */

    /// @dev Create a new submission.
    /// @param _name Name of the submission.
    /// @param _externalAddress Off-chain content hash of submission details (ipfs hash)
    /// @param _author Author of this submission.
    /// @param _references Addresses of submissions referenced in creating this submission
    /// @param _contributors Contributors to this submission.
    /// @return (_roundIndex, _submissionIndex) Location of this submission.
	function createSubmission(string _name, bytes32 _externalAddress, address _author, address[] _references, address[] _contributors, bool _publicallyAccessible) public duringOpenSubmission whileTournamentOpen returns (uint256 _submissionIndex)
	{
		uint256 timeSubmitted = now;
		bytes32[] memory externalAddress_Versioned;
		externalAddress_Versioned[0] = _externalAddress;
		
        Submission memory submission = Submission(tournamentAddress, _name, _author, externalAddress_Versioned, _references, _contributors, timeSubmitted, _publicallyAccessible, 0);
        
        // submission bookkeeping
        submissions.push(submission);
        contributorToSubmissionArray[msg.sender].push(submission);
        externalAddressToSubmission[_externalAddress] = submission;

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(participantType.author);
        for(uint256 i = 0; i < _contributors.length; i++)
        {
        	addressToParticipantType[_contributors[i]] = uint(participantType.contributor);
        }

        Tournament(tournamentAddress).InvokeSubmissionCreatedEvent(roundIndex, submissions.length-1);
        return submissions.length-1;
	}

	// TODO: Uncomment and complete.
	// function withdrawReward(uint256 _submissionIndex) public afterWinnerSelected onlySubmissionAuthor(_submissionIndex)
	// {

	// 	// uint submissionReward = submissions[_submissionIndex].balance;
	// 	// submissions[_submissionIndex].balance = 0;
	// 	//MatryxToken(matryxToken).transfer(msg.sender, submissionReward);
	// } 
	
	// TODO: Uncomment and complete.
	// function withdrawReward(uint256 _submissionIndex, address _recipient) public afterWinnerSelected onlySubmissionAuthor(_submissionIndex)
	// {
	// 	uint submissionReward = submissions[_submissionIndex].balance;
	// 	submissions[_submissionIndex].balance = 0;
	// 	MatryxToken(matryxToken).transfer(_recipient, submissionReward);
	// }
}