pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
import "../interfaces/IMatryxToken.sol";
import "../interfaces/IMatryxPlatform.sol";
import "../interfaces/IMatryxTournament.sol";
import "../interfaces/IMatryxRound.sol";
import "../interfaces/factories/IMatryxRoundFactory.sol";
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

    mapping(bytes32=>address) private contracts;

    uint256 public roundIndex;
    address public previousRound;
    address public nextRound;
    uint256 startTime;
    uint256 endTime;
    uint256 public reviewPeriodDuration;
    uint256 public bounty;
    address[] public winningSubmissions;
    uint256[] public rewardDistribution;
    uint256 public rewardDistributionTotal;
    mapping(address=>bool) submissionToHasBeenPayed;
    bool public closed;
    address newRound;

    mapping(address=>uint) addressToParticipantType;
    mapping(address=>address[]) authorToSubmissionAddress;
    mapping(address=>uint256_optional) addressToSubmissionIndex;
    address[] submissions;
    address[] submissionOwners;
    uint256 numberSubmissionsRemoved;

    constructor(address _platformAddress, address _matryxTokenAddress, address _tournamentAddress, address _submissionFactoryAddress, address _owner, uint256 _roundIndex, LibConstruction.RoundData roundData) public
    {
        //matryxTokenAddress = _matryxTokenAddress;
        platformAddress = _platformAddress;
        tournamentAddress = _tournamentAddress;
        owner = _owner;
        roundIndex = _roundIndex;
        matryxSubmissionFactoryAddress = _submissionFactoryAddress;
        bounty = roundData.bounty;

        bytes32 tournamentAdminLibHash = sha3("LibTournamentAdminMethods");
        contracts[tournamentAdminLibHash] = IMatryxRoundFactory(msg.sender).getContractAddress(tournamentAdminLibHash);
        
        scheduleStart(roundData.start, roundData.end, roundData.reviewPeriodDuration);
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
    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum ParticipantType { Nonentrant, Entrant, Contributor, Author }

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
    modifier duringReviewPeriod()
    {
        require(endTime != 0);
        require(getState() == uint256(RoundState.InReview));
        _;
    }

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

    modifier onlyTournamentOrLib()
    {
        bool isTournament = msg.sender == tournamentAddress;
        bool isLib = getContractAddress(sha3("LibTournamentAdminMethods")) == msg.sender;
        _;
    }

    /// @dev Requires that the desired submission is accessible to the requester.
    modifier whenAccessible(address _requester, uint256 _index)
    {
        require(IMatryxSubmission(submissions[_index]).isAccessible(_requester));
        _;
    }

    function submissionExists(address _submissionAddress) public returns (bool)
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

    function addBounty(uint256 _mtxAllocation) public onlyTournamentOrLib
    {
        bounty = bounty.add(_mtxAllocation);
    }

    /*
     * Access Control Methods
     */

    /// @dev Sets an address for a contract the platform should know about.
    /// @param _nameHash Keccak256 hash of the name of the contract to give an address to.
    /// @param _contractAddress Address to be assigned for the given contract name.
    function setContractAddress(bytes32 _nameHash, address _contractAddress) public onlyOwner
    {
        contracts[_nameHash] = _contractAddress;
    }

    /// @dev Gets the address of a contract the platform knows about.
    /// @param _nameHash Keccak256 hash of the name of the contract to look for.
    /// @return Address of the contract with the designated name.
    function getContractAddress(bytes32 _nameHash) public returns (address contractAddress)
    {
        return contracts[_nameHash];
    }

    // @dev Returns the state of the round. 
    // The round can be in one of 6 states:
    // NotYetOpen, Open, InReview, HasWinners, Closed, Abandoned
    function getState() public view returns (uint256)
    {
        if(now < startTime)
        {
            return uint256(RoundState.NotYetOpen);
        }
        else if(now >= startTime && now < endTime)
        {
            if (getRoundBalance() == 0)
            {
                return uint256(RoundState.Unfunded);
            }

            return uint256(RoundState.Open);
        }
        else if(now >= endTime && now < endTime.add(reviewPeriodDuration))
        {
            if(closed)
            {
                return uint256(RoundState.Closed);
            }
            else if(submissions.length == 0)
            {
                return uint256(RoundState.Abandoned);
            }
            else if(winningSubmissions.length > 0)
            {
                return uint256(RoundState.HasWinners);
            }

            return uint256(RoundState.InReview);
        }
        else if(winningSubmissions.length > 0)
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
    function submissionIsAccessible(uint256 _index) public view returns (bool)
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
    function requesterIsContributor(address _requester) public view returns (bool)
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

    function getPlatform() public view returns (address) {
        return platformAddress;
    }

    function getTournament() public view returns (address) {
        return tournamentAddress;
    }

    function getStartTime() public view returns (uint256)
    {
        return startTime;
    }

    function getEndTime() public view returns (uint256)
    {
        return endTime;
    }

    function getBounty() public view returns (uint256) 
    { 
        return bounty;
    }

    function remainingBounty() public view returns (uint256)
    {
        return IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).balanceOf(this);
    }

    function getTokenAddress() public view returns (address)
    {
        return IMatryxPlatform(platformAddress).getTokenAddress();
    }

    /// @dev Returns all submissions made to this round.
    /// @return _submissions All submissions made to this round.
    function getSubmissions() public view returns (address[] _submissions)
    {
        return submissions;
    }

    function getSubmissionAddress(uint256 _index) public view returns (address _submissionAddress)
    {
        require(_index < submissions.length);

        return submissions[_index];
    }

    /// @dev Returns the author of a submission.
    /// @param _index Index of the submission.
    /// @return Address of this submission's author.
    function getSubmissionAuthor(uint256 _index) public view whenAccessible(msg.sender, _index) returns (address) 
    {
        IMatryxSubmission submission = IMatryxSubmission(submissions[_index]);
        return submission.getAuthor();
    }

    /// @dev Returns the balance of a particular submission
    /// @param _submissionAddress Address of the submission
    /// @return Balance of the bounty 
    function getBalance(address _submissionAddress) public view returns (uint256)
    {
        return IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).balanceOf(_submissionAddress);
    }

    function getRoundBalance() public view returns (uint256)
    {
        return IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).balanceOf(this);
    }

    /// @dev Returns whether or not a winning submission has been chosen.
    /// @return Whether or not a submission has been chosen.
    function submissionsChosen() public view returns (bool)
    {
        return winningSubmissions[0] != 0x0;
    }

    /// @dev Returns the index of this round's winning submission.
    /// @return Index of the winning submission.
    function getWinningSubmissionAddresses() public view returns (address[])
    {
        return winningSubmissions;
    }

    /// @dev Returns the number of submissions made to this round.
    /// @return Number of submissions made to this round.
    function numberOfSubmissions() public view returns (uint256)
    {
        return submissions.length - numberSubmissionsRemoved;
    }

    function getParticipantType(address _participant) public view returns (uint256)
    {
        return addressToParticipantType[_participant];
    }

    /*
     * Round Admin Methods
     */


    /// @dev Starts the round (callable only by the owner of the round).
    /// @param _start Start time.
    /// @param _end End time.
    /// @param _reviewPeriodDuration Time to review the round submissions
    function scheduleStart(uint256 _start, uint256 _end, uint256 _reviewPeriodDuration) internal
    {
        startTime = _start;
        endTime = _end;
        reviewPeriodDuration = _reviewPeriodDuration;
    }

    /// @dev Allows the tournament to edit the 
    function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public onlyTournament
    {
        require(_roundData.start > _currentRoundEndTime);
        require(_roundData.end > _roundData.start);
        require(_roundData.reviewPeriodDuration > 0);
        require(_roundData.end.sub(_roundData.start) > 0);

        startTime = _roundData.start;
        endTime = _roundData.end;
        reviewPeriodDuration = _roundData.reviewPeriodDuration;
    }

    function transferToTournament(uint256 _amount) public onlyTournament 
    {
        require(getState() == uint256(RoundState.NotYetOpen));
        require(IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(msg.sender, _amount));
    }

    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
    /// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _submissionAddresses Index of the winning submission.
    /// @param _rewardDistribution Distribution indicating how to split the reward among the submissions
    function selectWinningSubmissions(address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public onlyTournamentOrLib duringReviewPeriod
    {
        require(_submissionAddresses.length == _rewardDistribution.length);
        require(_submissionAddresses.length != 0 && winningSubmissions.length == 0);

        winningSubmissions = _submissionAddresses;
        rewardDistribution = _rewardDistribution;

        uint256 _rewardDistributionTotal;
        for(uint256 i = 0; i < rewardDistribution.length; i++)
        {
            _rewardDistributionTotal = _rewardDistributionTotal.add(rewardDistribution[i]);
        }

        rewardDistributionTotal = _rewardDistributionTotal;

        // DoNothing and StartNextRound cases
        if(_selectWinnerAction == uint256(SelectWinnerAction.DoNothing) || _selectWinnerAction == uint256(SelectWinnerAction.StartNextRound))
        {
            for(uint256 j = 0; j < winningSubmissions.length; j++)
            {
                // Calculate total reward denominator and store it somewhere when
                uint256 reward = rewardDistribution[j].mul(10**18).div(rewardDistributionTotal).mul(bounty).div(10**18);
                // Transfer the reward to the submission
                require(IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(winningSubmissions[j], reward));
                IMatryxSubmission(winningSubmissions[j]).addToWinnings(reward);
            }

            uint256 newBounty;
            uint256 tournamentBalance = IMatryxTournament(tournamentAddress).getBalance();

            if(tournamentBalance < bounty)
            {
                newBounty = tournamentBalance;
            }
            else
            {
                newBounty = bounty;
            }

            LibConstruction.RoundData memory roundData;
            if(_selectWinnerAction == uint256(SelectWinnerAction.DoNothing))
            {
                roundData = LibConstruction.RoundData({start: endTime.add(reviewPeriodDuration), end: endTime.add(reviewPeriodDuration).add(endTime.sub(startTime)), reviewPeriodDuration: reviewPeriodDuration, bounty: newBounty});
                newRound = IMatryxTournament(tournamentAddress).createRound(roundData, true);
            }
            else if(_selectWinnerAction == uint256(SelectWinnerAction.StartNextRound))
            {
                closed = true;
                roundData = LibConstruction.RoundData({start: now, end: _roundData.end, reviewPeriodDuration: _roundData.reviewPeriodDuration, bounty: _roundData.bounty});
                newRound = IMatryxTournament(tournamentAddress).createRound(roundData, false);
            }
        }
        else
        {
            // CloseTournament case
            closed = true;
        }
    }

    function transferAllToWinners(uint256 _tournamentBalance) public onlyTournament
    {
        for(uint256 i = 0; i < winningSubmissions.length; i++)
        {
            // Calculate total reward denominator and store it somewhere when
            uint totalBalance = bounty.add(_tournamentBalance);
            uint256 reward = rewardDistribution[i].mul(1*10**18).div(rewardDistributionTotal).mul(totalBalance).div(1*10**18);
            // Transfer the reward to the submission
            IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(winningSubmissions[i], reward);
        }
    }

    function startNow() public onlyTournament
    {
        uint256 duration = endTime.sub(startTime);
        startTime = now;
        endTime = startTime.add(duration);
    }

    function closeRound() public onlyTournament
    {
        require(getState() == uint256(RoundState.HasWinners));
        closed = true;
    }

    /*
     * Entrant Methods
     */

    function becomeEntrant(address _entrant) public onlyTournament
    {
        addressToParticipantType[_entrant] = uint256(ParticipantType.Entrant);
    }

    function becomeNonentrant(address _entrant) public onlyTournament
    {
        addressToParticipantType[_entrant] = uint256(ParticipantType.Nonentrant);
    }

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
    function createSubmission(address[] _contributors, uint128[] _contributorRewardDistribution, address[] _references, address _author, LibConstruction.SubmissionData submissionData) public onlyTournament duringOpenSubmission returns (address _submissionAddress)
    {
        require(_author != 0x0);
        
        LibConstruction.RequiredSubmissionAddresses memory requiredSubmissionAddresses = LibConstruction.RequiredSubmissionAddresses({platformAddress: platformAddress, tournamentAddress: tournamentAddress, roundAddress: this});
        address submissionAddress = IMatryxSubmissionFactory(matryxSubmissionFactoryAddress).createSubmission(_contributors, _contributorRewardDistribution, _references, requiredSubmissionAddresses, submissionData);
        // submission bookkeeping
        addressToSubmissionIndex[submissionAddress] = uint256_optional({exists:true, value: submissions.length});
        submissions.push(submissionAddress);

        // TODO: Change to 'authors.push' once MatryxPeer is part of MatryxPlatform
        if(authorToSubmissionAddress[msg.sender].length == 0)
        {
            submissionOwners.push(submissionData.owner);
        }

        authorToSubmissionAddress[msg.sender].push(submissionAddress);

        // round participant bookkeeping
        addressToParticipantType[_author] = uint(ParticipantType.Author);
        for(uint256 i = 0; i < _contributors.length; i++)
        {
            addressToParticipantType[_contributors[i]] = uint(ParticipantType.Contributor);
        }

        IMatryxTournament(tournamentAddress).invokeSubmissionCreatedEvent(submissionAddress);
        //emit TimeStamp(now);
        return submissionAddress;
    }

    /// @dev Allows contributors to withdraw a portion of the round bounty if the round has been abandoned.
    function transferBountyToTournament() public onlyTournament returns (uint256)
    {  
        uint256 remaining = remainingBounty();
        IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(tournamentAddress, remaining);
        return remaining;
    }

    // function pullPayoutIntoSubmission() public onlySubmission returns (uint256)
    // {
    //     require(getState() == uint256(RoundState.Closed));
    //     // If the submission's already been paid, revert
    //     require(submissionToHasBeenPayed[msg.sender] == false);
    //     // If the tournament closed, we need to pull the tournament funds into this round.
    //     if(IMatryxTournament(tournamentAddress).getState() == uint256(TournamentState.Closed) && remainingBounty() > 0)
    //     {
    //         IMatryxTournament(tournamentAddress).pullRemainingBountyIntoRound();
    //     }

    //     // Transfer the reward to its recipient if it deserves a reward (and mark that its been given out)
        
    //     for(uint256 i = 0; i < winningSubmissions.length; i++)
    //     {
    //         if(msg.sender == winningSubmissions[i])
    //         {
    //             submissionToHasBeenPayed[msg.sender] = true;
    //             // Calculate total reward denominator and store it somewhere when
    //             uint256 reward = (rewardDistribution[i].mul(1*10**18).div(rewardDistributionTotal)).mul(bounty);
    //             // Transfer the reward to the submission
    //             IMatryxToken(matryxTokenAddress).transfer(msg.sender, reward);
    //             return reward;
    //         }
    //     }

    //     // TODO:
    //     // Or we could never transfer funds to the round in the first place.
    //     // This would allow this function to exist on the tournament instead of the round.
    //     // I'd need to reintroduce bountyLeft so that the tournament knew how much is left for the round.
    //     // If I reintroduced it, it would be to the tournament, so that submission.withdrawReward wouldn't have to call round.bountyLeft to figure out how much to ask the tournament for.
    //     // The tournament would just transfer as much as the submission deserved into it.
    //     // bountyLeft would be stored as a value under a rounds structure.
    //     // This would eventually involve writing a library to do round functions.
    //     // For now, this can be a hardcoded library.
    //     // Eventually, this library will be part of the upgrade system.
    //     // Upgrade system will eventually allow for data, data migration and code contracts to exist and be swapped per contract
    //     // All data and code contract addresses will be sourced from one contract, the MatryxVersionManager.
    //     // This contract will also contain data migrators to migrate from one version to another (for when data structures change)
    // }
}