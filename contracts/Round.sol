pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './Ownable.sol';
import './Tournament.sol';
import './MatryxToken.sol';
import './Submission.sol';

/// @title Round - A round within a Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract Round is Ownable {
	using SafeMath for uint256;
	using Submission for Submission.MatryxSubmission;

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
	uint256 public bountyMTX;
	uint256 public winningSubmissionIndex;
	bool public winningSubmissionChosen;

	mapping(address => uint) addressToParticipantType;
 	mapping(address => Submission.MatryxSubmission) authorToSubmission;
	mapping(bytes32 => Submission.MatryxSubmission) externalAddressToSubmission;
	Submission.MatryxSubmission[] submissions;

	function Round(uint256 _bountyMTX) public
	{
		tournamentAddress = msg.sender;
		bountyMTX = _bountyMTX;
		winningSubmissionChosen = false;
	}

    /*
     * Enums
     */

	enum participantType { nonentrant, entrant, contributor, author }

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
		require(submissions[_index].isAccessible(_requester));
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
		if(submissions.length - 1 < _index)
		{
			return false;
		}

		Submission.MatryxSubmission storage submission = submissions[_index];

		return submission.isAccessible(_requester);
	}

	function requesterIsEntrant(address _requester) public constant returns (bool)
	{
		return addressToParticipantType[_requester] != 0;
	}

	/*
     * Getter Methods
     */

	/// @dev Returns all submissions made to this round.
	/// @return _submissions All submissions made to this round.
	function getSubmissions() public constant returns (Submission.MatryxSubmission[] _submissions)
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
	function getSubmission(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (bytes32 externalAddress_Versioned)
	{
		Submission.MatryxSubmission storage submission = submissions[_index];
		return submission.getExternalAddress();
	}

	/// @dev Returns the author of a submission.
	/// @param _index Index of the submission.
	/// @return Address of this submission's author.
	function getSubmissionAuthor(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (address) 
	{
		return submissions[_index].author;
	}

	function submissionChosen() public constant returns (bool)
	{
		return winningSubmissionChosen;
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

		uint256 tempBalance = bountyMTX;
		bountyMTX = 0;
		submissions[winningSubmissionIndex].setBalance(tempBalance);
		
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
		require(_author != 0x0);
		
        Submission.MatryxSubmission memory submission = Submission.MatryxSubmission(tournamentAddress, this, _name, _author, _externalAddress, _references, _contributors, now, _publicallyAccessible, 0);
        
        // submission bookkeeping
        submissions.push(submission);
        authorToSubmission[msg.sender] = submission;
        externalAddressToSubmission[_externalAddress] = submission;

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(participantType.author);
        for(uint256 i = 0; i < _contributors.length; i++)
        {
        	addressToParticipantType[_contributors[i]] = uint(participantType.contributor);
        }

        Tournament(tournamentAddress).invokeSubmissionCreatedEvent(roundIndex, submissions.length-1);
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