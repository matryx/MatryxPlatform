pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/math/SafeMath.sol";
import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";
import "../libraries/LibIterable.sol";
import "../libraries/LibEnums.sol";
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
contract MatryxRound is IMatryxRound {
    using SafeMath for uint256;

    // TODO: allow for refunds
    // TODO: condense and put in structs

    address public platformAddress;
    address public tournamentAddress;
    address public matryxSubmissionFactoryAddress;

    LibConstruction.RoundData data;
    LibRound.SelectWinnersData winningSubmissionsData;
    LibRound.SubmissionsData submissionsData;
    LibRound.SubmissionAndEntrantTracking submissionEntrantTrackingData;

    constructor(address _platformAddress, address _tournamentAddress, address _submissionFactoryAddress, LibConstruction.RoundData _roundData) public
    {
        platformAddress = _platformAddress;
        tournamentAddress = _tournamentAddress;
        matryxSubmissionFactoryAddress = _submissionFactoryAddress;

        data.start = _roundData.start;
        data.end = _roundData.end;
        data.reviewPeriodDuration = _roundData.reviewPeriodDuration;
        data.bounty = _roundData.bounty;
    }

    /*
     * Modifiers
     */

    /// @dev Requires that this round is in the open submission state.
    modifier duringOpenRound()
    {
        require(getState() == uint256(LibEnums.RoundState.Open));
        _;
    }

    /// @dev Requires that this round is in the winner selection state.
    modifier duringReviewPeriod()
    {
        require(data.end != 0);
        require(getState() == uint256(LibEnums.RoundState.InReview));
        _;
    }

    /// @dev Requires that this round already has chosen winners
    modifier hasWinners()
    {
        require(getState() == uint256(LibEnums.RoundState.HasWinners));
        _;
    }

    // @dev Requires that a winner has been selected for this round.
    // modifier afterWinnerSelected()
    // {
    // 	require(winningSubmissions[0] != 0x0);
    // 	_;
    // }

    // Unused
    // modifier onlySubmission()
    // {
    //     require(submissionEntrantTrackingData.submissionExists[msg.sender]);
    //     _;
    // }

    modifier onlyTournament()
    {
        require(msg.sender == tournamentAddress);
        _;
    }

    // Unused
    /// @dev Requires that the desired submission is accessible to the requester.
    // modifier whenAccessible(address _requester, uint256 _index)
    // {
    //     require(IMatryxSubmission(submissionsData.submissions[_index]).isAccessible(_requester));
    //     _;
    // }

    function submissionExists(address _submissionAddress) public view returns (bool)
    {
        return submissionEntrantTrackingData.submissionExists[_submissionAddress];
    }

    /// @dev Requires the function caller to be the platform or the owner of this tournament
    // modifier tournamentOrOwner()
    // {
    //     require((msg.sender == tournamentAddress)||(msg.sender == owner));
    //     _;
    // }

    // Unused
    // @dev Requires that the sender be the submission's author.
    // modifier onlySubmissionAuthor()
    // {
    //     require(submissionEntrantTrackingData.authorToSubmissionAddress[msg.sender].length != 0);
    //     _;
    // }

    /*
     * State Maintenance Methods
     */

    // function removeSubmission(address _submissionAddress) public onlyTournament returns (bool)
    // {
            // TODO: Implement with LLLLL (optimized linked list)
    // 	}
    // }

    function addBounty(uint256 _mtxAllocation) public onlyTournament
    {
        data.bounty = data.bounty.add(_mtxAllocation);
    }

    /*
     * Access Control Methods
     */

    //TODO - LLL THIS Function
    // @dev Returns the state of the round.
    // The round can be in one of 6 states:
    // NotYetOpen, Open, InReview, HasWinners, Closed, Abandoned
    function getState() public view returns (uint256)
    {
        return LibRound.getState(platformAddress, data, winningSubmissionsData, submissionsData);
    }

    /*
     * Getter Methods
     */

    function getPlatform() public view returns (address)
    {
        return platformAddress;
    }

    function getTournament() public view returns (address)
    {
        return tournamentAddress;
    }

    function getData() public view returns (LibConstruction.RoundData _roundData) {
        return data;
    }

    function getStartTime() public view returns (uint256)
    {
        return data.start;
    }

    function getEndTime() public view returns (uint256)
    {
        return data.end;
    }

    function getReviewPeriodDuration() public view returns (uint256)
    {
        return data.reviewPeriodDuration;
    }

    function getBounty() public view returns (uint256)
    {
        return data.bounty;
    }

    function getRemainingBounty() public view returns (uint256)
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
        return submissionsData.submissions;
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
        return winningSubmissionsData.winningSubmissions.length != 0;
    }

    /// @dev Returns the index of this round's winning submission.
    /// @return Index of the winning submission.
    function getWinningSubmissionAddresses() public view returns (address[])
    {
        return winningSubmissionsData.winningSubmissions;
    }

    /// @dev Returns the number of submissions made to this round.
    /// @return Number of submissions made to this round.
    function numberOfSubmissions() public view returns (uint256)
    {
        return submissionsData.submissions.length;
    }

    /*
     * Round Admin Methods
     */

    /// @dev Allows the tournament to edit the
    function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public onlyTournament
    {
        LibRound.editRound(data, _currentRoundEndTime, _roundData);
    }

    function transferToTournament(uint256 _amount) public onlyTournament
    {
        require(getState() == uint256(LibEnums.RoundState.NotYetOpen));
        require(IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(msg.sender, _amount));
    }

    /// @dev Choose a winning submission for the round (callable only by the owner of the round).
    /// @param _selectWinnersData Data containing:
    ///   winningSubmissions: Addresses of the winning submissions
    ///   rewardDistribution: Distribution indicating how to split the MTX reward among the submissions
    ///   rewardDistributionTotal: (Unused)
    /// @param _roundData Data containing:
    ///   start: Start time (seconds since unix-epoch) for next round
    ///   end: End time (seconds since unix-epoch) for next round
    ///   reviewPeriodDuration: Number of seconds to allow for winning submissions to be selected in next round
    ///   bounty: Bounty in MTX for next round
    ///   closed: (Unused)
    function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public onlyTournament duringReviewPeriod
    {
        LibRound.selectWinningSubmissions(data, winningSubmissionsData, _selectWinnersData, _roundData);
    }

    /// @dev Allows contributors to withdraw a portion of the round bounty if the round has been abandoned.
    function transferBountyToTournament() public onlyTournament returns (uint256)
    {
        uint256 remaining = getRemainingBounty();
        IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(tournamentAddress, remaining);
        return remaining;
    }

    function transferAllToWinners(uint256 _tournamentBalance) public onlyTournament
    {
        // Calculate total reward denominator
        uint256 totalBalance = data.bounty.add(_tournamentBalance).mul(10**18);
        uint256 totalDist = winningSubmissionsData.rewardDistributionTotal.mul(10**18);

        for(uint256 i = 0; i < winningSubmissionsData.winningSubmissions.length; i++)
        {
            // Calculate reward numerator based on distribution for this specific submission
            // uint256 reward = winningSubmissionsData.rewardDistribution[i].mul(1*10**18).div(winningSubmissionsData.rewardDistributionTotal).mul(totalBalance).div(1*10**18);
            uint256 reward = winningSubmissionsData.rewardDistribution[i].mul(totalBalance).div(totalDist);
            // Transfer the reward to the submission
            IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).transfer(winningSubmissionsData.winningSubmissions[i], reward);
            IMatryxSubmission(winningSubmissionsData.winningSubmissions[i]).addToWinnings(reward);
        }
    }

    function startNow() public onlyTournament
    {
        uint256 duration = data.end.sub(data.start);
        data.start = now;
        data.end = data.start.add(duration);
    }

    function closeRound() public onlyTournament hasWinners
    {
        data.closed = true;
    }

    /*
     * Entrant Methods
     */

    /// @dev Create a new submission. Called by MatryxTournament
    /// @param _owner Owner of this submission.
    /// @param submissionData The data of the submission. Includes:
    ///		title: Title of the submission.
    ///		owner: The owner of the submission.
    ///		contentHash: Off-chain content hash of submission details (ipfs hash)
    ///		contributors: Contributors to this submission.
    ///		contributorRewardDistribution: Informs how the reward should be distributed among the contributors
    /// 	should this submission win.
    ///		references: Addresses of submissions referenced in creating this submission.
    /// @return _submissionAddress Location of this submission within this round.
    function createSubmission(address _owner, address platformAddress, LibConstruction.SubmissionData submissionData) public onlyTournament duringOpenRound returns (address _submissionAddress)
    {
        require(_owner != 0x0);

        address submissionAddress = IMatryxSubmissionFactory(matryxSubmissionFactoryAddress).createSubmission(_owner, platformAddress, tournamentAddress, this, submissionData);
        // submission bookkeeping
        submissionEntrantTrackingData.submissionExists[submissionAddress] = true;
        submissionsData.submissions.push(submissionAddress);
        // TODO: Change to 'authors.push' once MatryxPeer is part of MatryxPlatform
        if(submissionEntrantTrackingData.authorToSubmissionAddress[_owner].length == 0)
        {
            submissionsData.submissionOwners.push(_owner);
        }

        submissionEntrantTrackingData.authorToSubmissionAddress[_owner].push(submissionAddress);

        IMatryxTournament(tournamentAddress).invokeSubmissionCreatedEvent(submissionAddress);
        return submissionAddress;
    }

    // function pullPayoutIntoSubmission() public onlySubmission returns (uint256)
    // {
    //     require(getState() == uint256(LibEnums.RoundState.Closed));
    //     // If the submission's already been paid, revert
    //     require(submissionToHasBeenPayed[msg.sender] == false);
    //     // If the tournament closed, we need to pull the tournament funds into this round.
    //     if(IMatryxTournament(tournamentAddress).getState() == uint256(LibEnums.TournamentState.Closed) && getRemainingBounty() > 0)
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
