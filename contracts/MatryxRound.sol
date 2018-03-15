pragma solidity ^0.4.18;

import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/factories/IMatryxSubmissionFactory.sol';
import '../interfaces/IMatryxSubmission.sol';
import './Ownable.sol';

/// @title MatryxRound - A round within a Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract MatryxRound is Ownable, IMatryxRound {
	using SafeMath for uint256;

	//TODO: time restriction on review period
	//TODO: allow for refunds

	address public tournamentAddress;
	address public matryxSubmissionFactoryAddress;
	address public matryxTokenAddress;

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
 	mapping(address => address) authorToSubmissionAddress;
	mapping(bytes32 => address) externalAddressToSubmission;
	mapping(address => bool)  submissionExists;
	address[] submissions;
	mapping(address => uint256) submissionToBalance;

	function MatryxRound(address _tournamentAddress, address _matryxSubmissionFactoryAddress, address _owner, uint256 _bountyMTX) public
	{
		tournamentAddress = _tournamentAddress;
		owner = _owner;
		matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
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
		require(isOpen());
		_;
	}

	/// @dev Requires that this round is in the winner selection state.
	modifier duringWinnerSelection()
	{
		//require(endTime != 0);
		require(now >= endTime);
		require(winningSubmissionChosen == false);
		_;
	}

	/// @dev Requires that a winner has been selected for this round.
	// modifier afterWinnerSelected()
	// {
	// 	require(winningSubmissionChosen == true);
	// 	_;
	// }

	modifier onlyTournament()
	{
		require(msg.sender == tournamentAddress);
		_;
	}

	/// @dev Requires that this round's tournament is open.
	modifier whileTournamentOpen()
	{
		IMatryxTournament tournament = IMatryxTournament(tournamentAddress);
		require(tournament.tournamentOpen());
		_;
	}

	/// @dev Requires that the desired submission is accessible to the requester.
	modifier whenAccessible(address _requester, uint256 _index)
	{
		require(IMatryxSubmission(submissions[_index]).isAccessible(_requester));
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
	// 	require(submissionExists[_submissionAddress]);

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

	/*
     * Getter Methods
     */

    function getTournament() public constant returns (address)
	{
		return tournamentAddress;
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

	/// @dev Returns a hash of the contents of a submission.
	/// @param _index Index of the requested submission.
	/// @return _name Name of the submission.
	/// @return _author Author of the submission.
	/// @return _externalAddress Off-chain content hash of submission details (ipfs hash).
	/// @return _references Addresses of submissions referenced in creating this submission
    /// @return _contributors Contributors to this submission.
	/// @return _timeSubmitted Epoch time this this submission was made.
	function getSubmissionBody(uint256 _index) public constant whenAccessible(msg.sender, _index) returns (bytes32 externalAddress)
	{
		IMatryxSubmission submission = IMatryxSubmission(submissions[_index]);
		return submission.getExternalAddress();
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
	function getBalance(address _submissionAddress) public returns (uint256)
	{
		return submissionToBalance[_submissionAddress];
	}

	/// @dev Returns whether or not a winning submission has been chosen.
	/// @return Whether or not a submission has been chosen.
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
	function Start(uint256 _duration) public
	{
		require(startTime == 0);
		startTime = now;
		endTime = startTime.add(_duration);
	}

	/// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _submissionIndex Index of the winning submission.
	function chooseWinningSubmission(uint256 _submissionIndex) public tournamentOrOwner whileTournamentOpen duringWinnerSelection
	{
		require(_submissionIndex < submissions.length);
		//TODO: apply time restrictions.
		winningSubmissionIndex = _submissionIndex;

		submissionToBalance[submissions[_submissionIndex]] = bountyMTX;
		bountyMTX = 0;
		winningSubmissionChosen = true;
	}

	/// @dev Award bounty to a submission. Called by tournament to close a tournament after a 
	/// round winner has been chosen.
	/// @param _submissionIndex Index of the tournament winning submission.
	/// @param _remainingBounty Bounty to award the submission.
	function awardBounty(uint256 _submissionIndex, uint256 _remainingBounty) public onlyTournament
	{
		submissionToBalance[submissions[_submissionIndex]] += _remainingBounty;
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
	function createSubmission(string _title, address _author, bytes32 _externalAddress, address[] _references, address[] _contributors, bool _publicallyAccessible) public onlyTournament whileTournamentOpen duringOpenSubmission returns (address _submissionAddress)
	{
		require(_author != 0x0);
		
        address submissionAddress = IMatryxSubmissionFactory(matryxSubmissionFactoryAddress).createSubmission(tournamentAddress, this, _title, _author, _externalAddress, _references, _contributors, now, _publicallyAccessible);
        
        //submission bookkeeping
        submissions.push(submissionAddress);
        submissionExists[submissionAddress] = true;
        authorToSubmissionAddress[msg.sender] = submissionAddress;
        externalAddressToSubmission[_externalAddress] = submissionAddress;

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(participantType.author);
        // TODO: Uncomment and test.
        // for(uint256 i = 0; i < _contributors.length; i++)
        // {
        // 	addressToParticipantType[_contributors[i]] = uint(participantType.contributor);
        // }

        IMatryxTournament tournament = IMatryxTournament(tournamentAddress);
        tournament.invokeSubmissionCreatedEvent(submissionAddress);
        return submissionAddress;
	}

	// TODO: Uncomment and complete.
	// function withdrawReward(uint256 _submissionIndex) public afterWinnerSelected onlySubmissionAuthor(_submissionIndex)
	// {

	// 	// uint submissionReward = submissionToBalance[submissions[_submissionIndex]];
	// 	// submissionToBalance[submissions[_submissionIndex]] = 0;
	// 	//MatryxToken(matryxTokenAddress).transfer(msg.sender, submissionReward);
	// } 
	
	// TODO: Uncomment and complete.
	// function withdrawReward(uint256 _submissionIndex, address _recipient) public afterWinnerSelected onlySubmissionAuthor(_submissionIndex)
	// {
	// 	uint submissionReward = submissionToBalance[submissions[_submissionIndex]];
	// 	submissionToBalance[submissions[_submissionIndex]] = 0;
	// 	MatryxToken(matryxTokenAddress).transfer(_recipient, submissionReward);
	// }
}