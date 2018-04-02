pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxToken.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/factories/IMatryxSubmissionFactory.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

/// @title MatryxRound - A round within a Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxRound is Ownable, IMatryxRound {
	using SafeMath for uint256;

	//TODO: allow for refunds
	// TODO: condense and put in structs
	address public platformAddress;
	address public tournamentAddress;
	address public matryxSubmissionFactoryAddress;
	address public matryxTokenAddress;

	uint256 public roundIndex;
	address public previousRound;
	address public nextRound;
	uint256 public startTime;
	uint256 public endTime;
	uint256 public reviewPeriod;
	uint256 public bounty;
	address public winningSubmission;
	bool winningSubmissionChosen;

	mapping(address=>uint) addressToParticipantType;
 	mapping(address=>address) authorToSubmissionAddress;
	mapping(address=>uint256_optional) addressToSubmissionIndex;
	address[] submissions;
	uint256 numberSubmissionsRemoved;

	function MatryxRound(address _matryxTokenAddress, address _platformAddress, address _tournamentAddress, address _matryxSubmissionFactoryAddress, address _owner, uint256 _bounty) public
	{
		matryxTokenAddress = _matryxTokenAddress;
		platformAddress = _platformAddress;
		tournamentAddress = _tournamentAddress;
		owner = _owner;
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
		bounty = _bounty;
		winningSubmissionChosen = false;
	}

	/*
	 * Structs
	 */

	struct uint256_optional
    {
        bool exists;
        uint256 value;
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
		require(isOpen());
		_;
	}

	/// @dev Requires that this round is in the winner selection state.
	modifier duringReviewPeriod()
	{
		//require(endTime != 0);
		require(isInReview());
		_;
	}

	// @dev Requires that a winner has been selected for this round.
	modifier afterWinnerSelected()
	{
		require(winningSubmissionChosen == true);
		_;
	}

	modifier onlySubmission()
	{
		require(addressToSubmissionIndex[msg.sender].exists);
		_;
	}

	modifier onlyTournament()
	{
		require(msg.sender == tournamentAddress);
		_;
	}

	/// @dev Requires that this round's tournament is open.
	modifier whileTournamentOpen()
	{
		IMatryxTournament tournament = IMatryxTournament(tournamentAddress);
		require(tournament.isOpen());
		_;
	}

	/// @dev Requires that the desired submission is accessible to the requester.
	modifier whenAccessible(address _requester, uint256 _index)
	{
		require(IMatryxSubmission(submissions[_index]).isAccessible(_requester));
		_;
	}

	modifier ifSubmissionExists(address _submissionAddress)
	{
		require(addressToSubmissionIndex[_submissionAddress].exists);
		_;
	}

	/// @dev Requires the function caller to be the platform or the owner of this tournament
	modifier tournamentOrOwner()
    {
        require((msg.sender == tournamentAddress)||(msg.sender == owner));
        _;
    }

	/// @dev Requires that the sender be the submission's author.
	// modifier onlySubmissionAuthor(uint256 _submissionIndex)
	// {
	// 	require(IMatryxSubmission(submissions[_submissionIndex]).getAuthor() == msg.sender);
	// 	_;
	// }

	/*
	 * State Maintenance Methods
	 */

	function removeSubmission(address _submissionAddress) public onlyTournament returns (bool)
	{
		if(addressToSubmissionIndex[msg.sender].exists)
		{
			IMatryxSubmission submission = IMatryxSubmission(submissions[addressToSubmissionIndex[_submissionAddress].value]);
			address author = submission.getAuthor();
			submission.deleteSubmission();

			delete authorToSubmissionAddress[author];
			delete submissions[addressToSubmissionIndex[_submissionAddress].value];

			numberSubmissionsRemoved = numberSubmissionsRemoved.add(1);
			return true;
		}

		return false;
	}

	/*
     * Access Control Methods
     */

	/// @dev Returns whether or not this round is open to new submissions.
	/// @return Whether or not this round is open to submissions.
    function isOpen() public constant returns (bool)
	{
		bool roundStartedBeforeNow = startTime <= now;
		bool roundEndsAfterNow = now <= endTime;
		bool winningSubmissionNotYetChosen = !winningSubmissionChosen;
		bool result = roundStartedBeforeNow && roundEndsAfterNow && winningSubmissionNotYetChosen;
		return result;
	}

	/// @dev Returns whether or not this round is in the review period.
	/// @return Whether or not the round is being reviewed.
	function isInReview() public constant returns (bool)
	{
		bool roundEndedAfterNow = now >= endTime;
		bool roundReviewNotOver = now <= endTime+reviewPeriod;
		return roundEndedAfterNow && roundReviewNotOver && !winningSubmissionChosen;
	}

	/// @dev Returns whether or not the submission is accessible to the requester.
	/// @param _index Index of the submission being requested.
    /// @return Whether or not the submission is accessible to the requester.
	function submissionIsAccessible(uint256 _index) public constant returns (bool)
	{
		require(_index < submissions.length);

		IMatryxSubmission submission = IMatryxSubmission(submissions[_index]);
		return submission.isAccessible(msg.sender);
	}

	/// @dev Returns whether or not the submission is accessible to the requester.
	/// @param _submissionAddress Address of the submission being requested.
    /// @return Whether or not the submission is accessible to the requester.
	// function submissionIsAccessible(address _submissionAddress) public constant returns (bool)
	// {
	// 	require(addressToSubmissionIndex[_submissionAddress]);

	// 	IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
	// 	return submission.isAccessible(msg.sender);
	// }

	/// @dev Returns true if the sender is an entrant in this round.
	/// @param _requester Address being tested.
	/// @return Whether or not the requester is a contributor in this round.
	function requesterIsContributor(address _requester) public constant returns (bool)
	{
		return addressToParticipantType[_requester] != 0;
	}

	function setParticipantType(address _participantAddress, uint256 _type) public onlySubmission
	{
		addressToParticipantType[_participantAddress] = _type;
	}

	/*
     * Getter Methods
     */

    function getPlatform() public constant returns (address) {
		return platformAddress;
	}

    function getTournament() public constant returns (address) {
		return tournamentAddress;
	}

    function getBounty() public constant returns (uint256) 
    { 
    	return bounty;
    }

    function getTokenAddress() public constant returns (address)
    {
    	return matryxTokenAddress;
    }

	/// @dev Returns all submissions made to this round.
	/// @return _submissions All submissions made to this round.
	function getSubmissions() public constant returns (address[] _submissions)
	{
		return submissions;
	}

	function getSubmissionAddress(uint256 _index) public constant returns (address _submissionAddress)
	{
		require(_index < submissions.length);

		return submissions[_index];
	}

	/// @dev Returns the author of a submission.
	/// @param _index Index of the submission.
	/// @return Address of this submission's author.
	function getSubmissionAuthor(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (address) 
	{
		IMatryxSubmission submission = IMatryxSubmission(submissions[_index]);
		return submission.getAuthor();
	}

	/// @dev Returns the balance of a particular submission
	/// @param _submissionAddress Address of the submission
	/// @return Balance of the bounty 
	function getBalance(address _submissionAddress) public constant returns (uint256)
	{
		return IMatryxToken(matryxTokenAddress).balanceOf(_submissionAddress);
	}

	/// @dev Returns whether or not a winning submission has been chosen.
	/// @return Whether or not a submission has been chosen.
	function submissionChosen() public constant returns (bool)
	{
		return winningSubmissionChosen;
	}

	/// @dev Returns the index of this round's winning submission.
	/// @return Index of the winning submission.
	function getWinningSubmissionAddress() public constant returns (address)
	{
		return winningSubmission;
	}

	/// @dev Returns the number of submissions made to this round.
	/// @return Number of submissions made to this round.
	function numberOfSubmissions() public constant returns (uint256)
	{
		return submissions.length - numberSubmissionsRemoved;
	}

	/*
     * Round Admin Methods
     */

    /// @dev Starts the round (callable only by the owner of the round).
    /// @param _duration Duration of the round in seconds.
	function Start(uint256 _duration, uint256 _reviewPeriod) public
	{
		require(startTime == 0);
		startTime = now;
		endTime = startTime.add(_duration);
		reviewPeriod = _reviewPeriod;
	}

	/// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _submissionAddress Index of the winning submission.
	function chooseWinningSubmission(address _submissionAddress) public onlyTournament ifSubmissionExists(_submissionAddress) duringReviewPeriod
	{
		winningSubmission = _submissionAddress;
		winningSubmissionChosen = true;

		IMatryxToken token = IMatryxToken(matryxTokenAddress);
		token.transfer(_submissionAddress, bounty);
	}

	/// @dev Award bounty to a submission. Called by tournament to close a tournament after a 
	/// round winner has been chosen.
	/// @param _submissionAddress Index of the tournament winning submission.
	/// @param _remainingBounty Bounty to award the submission.
	function awardBounty(address _submissionAddress, uint256 _remainingBounty) public onlyTournament ifSubmissionExists(_submissionAddress)
	{
		IMatryxToken token = IMatryxToken(matryxTokenAddress);
		token.transfer(_submissionAddress, _remainingBounty);
	}

	/*
     * Entrant Methods
     */

    /// @dev Create a new submission.
    /// @param _title Title of the submission.
    /// @param _externalAddress Off-chain content hash of submission details (ipfs hash)
    /// @param _author Author of this submission.
    /// @param _references Addresses of submissions referenced in creating this submission
    /// @param _contributors Contributors to this submission.
    /// @return _submissionIndex Location of this submission within this round.
	function createSubmission(string _title, address _owner, address _author, bytes _externalAddress, address[] _references, address[] _contributors, uint128[] _contributorRewardDistribution) public onlyTournament duringOpenSubmission returns (address _submissionAddress)
	{
		require(_author != 0x0);
		
        address submissionAddress = IMatryxSubmissionFactory(matryxSubmissionFactoryAddress).createSubmission(platformAddress, tournamentAddress, this, _title, _owner, _author, _externalAddress, _references, _contributors, _contributorRewardDistribution);
        //submission bookkeeping
        addressToSubmissionIndex[submissionAddress] = uint256_optional({exists:true, value: submissions.length});
        submissions.push(submissionAddress);
        authorToSubmissionAddress[msg.sender] = submissionAddress;

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(participantType.author);
        for(uint256 i = 0; i < _contributors.length; i++)
        {
        	addressToParticipantType[_contributors[i]] = uint(participantType.contributor);
        }

        IMatryxTournament(tournamentAddress).invokeSubmissionCreatedEvent(submissionAddress);
        return submissionAddress;
	}
}