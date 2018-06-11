pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
import "../interfaces/IMatryxToken.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/IMatryxRound.sol";
import "../interfaces/factories/IMatryxSubmissionFactory.sol";
import "../interfaces/IMatryxSubmission.sol";
import "./Ownable.sol";

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
    bool hasBeenWithdrawnFrom;
    mapping(address=>bool) hasWithdrawn;
    address[] public winningSubmissions;

    mapping(address=>uint) addressToParticipantType;
    mapping(address=>address[]) authorToSubmissionAddress;
    mapping(address=>uint256_optional) addressToSubmissionIndex;
    address[] submissions;
    address[] submissionOwners;
    uint256 numberSubmissionsRemoved;

	constructor(address _platformAddress, address _matryxTokenAddress, address _tournamentAddress, address _submissionFactoryAddress, address _owner, LibConstruction.RoundData roundData) public
	{
		matryxTokenAddress = _matryxTokenAddress;
		platformAddress = _platformAddress;
		tournamentAddress = _tournamentAddress;
		owner = _owner;
		matryxSubmissionFactoryAddress = _submissionFactoryAddress;
		bounty = roundData.bounty;

		scheduleStart(roundData.start, roundData.end, roundData.reviewDuration);
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
		require(getState() == uint256(RoundState.Open));
		_;
	}

	/// @dev Requires that this round is in the winner selection state.
	// modifier duringReviewPeriod()
	// {
	// 	//require(endTime != 0);
	// 	require(getState() == RoundInReview);
	// 	_;
	// }

	// @dev Requires that a winner has been selected for this round.
	// modifier afterWinnerSelected()
	// {
	// 	require(winningSubmissions[0] != 0x0);
	// 	_;
	// }

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

	/// @dev Requires that the desired submission is accessible to the requester.
    modifier whenAccessible(address _requester, uint256 _index)
    {
        require(IMatryxSubmission(submissions[_index]).isAccessible(_requester));
        _;
    }

    function submissionExists(address _submissionAddress) internal returns (bool)
    {
        return addressToSubmissionIndex[_submissionAddress].exists;
    }

	/// @dev Requires the function caller to be the platform or the owner of this tournament
	// modifier tournamentOrOwner()
    // {
    //     require((msg.sender == tournamentAddress)||(msg.sender == owner));
    //     _;
    // }

	// @dev Requires that the sender be the submission's author.
	modifier onlySubmissionAuthor()
	{
		require(authorToSubmissionAddress[msg.sender].length != 0);
		_;
	}

	/*
	 * State Maintenance Methods
	 */

	// function removeSubmission(address _submissionAddress) public onlyTournament returns (bool)
	// {
	// 	if(addressToSubmissionIndex[msg.sender].exists)
	// 	{
	// 		IMatryxSubmission submission = IMatryxSubmission(submissions[addressToSubmissionIndex[_submissionAddress].value]);
	// 		address author = submission.getAuthor();
	// 		submission.deleteSubmission();

	// 		delete authorToSubmissionAddress[author];
	// 		delete submissions[addressToSubmissionIndex[_submissionAddress].value];

	// 		numberSubmissionsRemoved = numberSubmissionsRemoved.add(1);
	// 		return true;
	// 	}

	// 	return false;
	// }

	/*
     * Access Control Methods
     */

    enum RoundState { NotYetOpen, Open, InReview, Closed, Abandoned }

	// @dev Returns the state of the round. 
	// The round can be in one of 5 states:
	// NotYetOpen, Open, InReview, Closed, Abandoned
	// TODO how do we keep track of the startTime, endTime, and winningSubmissions?
    function getState() public view returns (uint256)
    {
        if(now < startTime)
        {
            return uint256(RoundState.NotYetOpen);
        }
        else if(now > startTime && now < endTime)
        {
            return uint256(RoundState.Open);
        }
        else if(now >= endTime && now < endTime.add(reviewPeriod))
        {
            return uint256(RoundState.InReview);
        }
        else if(winningSubmissions[0] != 0x0)
        {
            return uint256(RoundState.Closed);
        }
        else
        {
            return uint256(RoundState.Abandoned);
        }
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
	function submissionIsAccessible(address _submissionAddress) public view returns (bool)
	{
		require(addressToSubmissionIndex[_submissionAddress].exists);

		IMatryxSubmission submission = IMatryxSubmission(_submissionAddress);
		return submission.isAccessible(msg.sender);
	}

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
	function submissionsChosen() public constant returns (bool)
	{
		return winningSubmissions[0] != 0x0;
	}

	/// @dev Returns the index of this round's winning submission.
	/// @return Index of the winning submission.
	function getWinningSubmissionAddresses() public constant returns (address[])
	{
		return winningSubmissions;
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
	/// @param _start Start time.
	/// @param _end End time.
	/// @param _reviewPeriod Time to review the round submissions
	function scheduleStart(uint256 _start, uint256 _end, uint256 _reviewPeriod) internal
	{
		startTime = _start;
		// require((now <= _start), "Scheduled start time has already passed! Please choose a start time in the future.");
		endTime = _end;
		reviewPeriod = _reviewPeriod;
	}

	/// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _submissionAddresses Index of the winning submission.
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
	function chooseWinningSubmissions(address[] _submissionAddresses, uint256[] _rewardDistribution) public onlyTournament /*duringReviewPeriod*/
	{
		require(_submissionAddresses.length == _rewardDistribution.length);

		winningSubmissions = _submissionAddresses;

		IMatryxToken token = IMatryxToken(matryxTokenAddress);

		for(uint256 i = 0; i < _submissionAddresses.length; i++)
		{
			require(submissionExists(_submissionAddresses[i]));
			token.transfer(_submissionAddresses[i], bounty.mul(1*10**18).div(_rewardDistribution[i]));
		}
	}

	/*
     * Entrant Methods
     */

    /// @dev Create a new submission.
    /// @param _author of this submission.
    /// @param submissionData The data of the submission. Includes:
    ///		title: Title of the submission.
    ///		owner: The owner of the submission.
    ///		contentHash: Off-chain content hash of submission details (ipfs hash)
    ///		contributors: Contributors to this submission.
    ///		contributorRewardDistribution: Informs how the reward should be distributed among the contributors
    /// 	should this submission win.
    ///		references: Addresses of submissions referenced in creating this submission.
    /// @return _submissionAddress Location of this submission within this round.
	function createSubmission(address _author, LibConstruction.SubmissionData submissionData) public onlyTournament duringOpenSubmission returns (address _submissionAddress)
	{
		require(_author != 0x0);
		
		LibConstruction.RequiredSubmissionAddresses memory requiredSubmissionAddresses = LibConstruction.RequiredSubmissionAddresses({platformAddress: platformAddress, tournamentAddress: tournamentAddress, roundAddress: this});
        address submissionAddress = IMatryxSubmissionFactory(matryxSubmissionFactoryAddress).createSubmission(requiredSubmissionAddresses, submissionData);
        //submission bookkeeping
        addressToSubmissionIndex[submissionAddress] = uint256_optional({exists:true, value: submissions.length});
        submissions.push(submissionAddress);

        // TODO: Change to 'authors.push' once MatryxPeer is part of MatryxPlatform
        if(authorToSubmissionAddress[msg.sender].length == 0)
        {
        	submissionOwners.push(submissionData.owner);
        }

        authorToSubmissionAddress[msg.sender].push(submissionAddress);

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(participantType.author);
        for(uint256 i = 0; i < submissionData.contributors.length; i++)
        {
        	addressToParticipantType[submissionData.contributors[i]] = uint(participantType.contributor);
        }

        IMatryxTournament(tournamentAddress).invokeSubmissionCreatedEvent(submissionAddress);
        return submissionAddress;
	}

	/// @dev Allows contributors to withdraw a portion of the round bounty if the round has been abandoned.
	function liquidate() public onlySubmissionAuthor
	{
		require(getState() == uint256(RoundState.Abandoned), "This tournament is still valid.");
		require(!hasWithdrawn[msg.sender]);

		if(!hasBeenWithdrawnFrom)
		{
			require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, bounty.div(submissionOwners.length).mul(2)));
		}
		else
		{
			uint256 numberOfOwners = submissionOwners.length;
			require(IMatryxToken(matryxTokenAddress).transfer(msg.sender, bounty.mul(numberOfOwners-2).div(numberOfOwners).div(numberOfOwners-1)));
		}

		hasWithdrawn[msg.sender] = true;
	}
}