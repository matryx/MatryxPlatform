pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

import "../LibConstruction.sol";
import "../math/SafeMath.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxTournament.sol";
import "../../interfaces/IMatryxRound.sol";
import "../../interfaces/IMatryxSubmission.sol";

library LibRound
{
    using SafeMath for uint256;

    struct WinningSubmissionData
    {
        //Round Winner Data
        address[] winningSubmissions;
        uint256[] rewardDistribution;
        uint256 rewardDistributionTotal;
    }

    struct SubmissionAndEntrantTracking
    {
        mapping(address=>uint) addressToParticipantType;
        mapping(address=>address[]) authorToSubmissionAddress;
        mapping(address=>bool) submissionExists;
    }

    struct SubmissionsData
    {
        address[] submissions;
        address[] submissionOwners;
    }

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    function editRound(LibConstruction.RoundData storage data, uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public
    {
        require(_roundData.start > _currentRoundEndTime);
        require(_roundData.end > _roundData.start);
        require(_roundData.reviewPeriodDuration > 0);
        require(_roundData.end.sub(_roundData.start) > 0);

        data.start = _roundData.start;
        data.end = _roundData.end;
        data.reviewPeriodDuration = _roundData.reviewPeriodDuration;
    }

    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
    // function selectWinningSubmissions(LibConstruction.RoundData storage data, LibRound.WinningSubmissionData storage winningSubmissionData, address[] _submissionAddresses, uint256[] _rewardDistribution, LibConstruction.RoundData _roundData, uint256 _selectWinnerAction) public
    // {
    //     require(_submissionAddresses.length == _rewardDistribution.length);
    //     require(_submissionAddresses.length != 0 && winningSubmissionData.winningSubmissions.length == 0);

    //     winningSubmissionData.winningSubmissions = _submissionAddresses;
    //     winningSubmissionData.rewardDistribution = _rewardDistribution;

    //     uint256 _rewardDistributionTotal;
    //     for(uint256 i = 0; i < winningSubmissionData.rewardDistribution.length; i++)
    //     {
    //         _rewardDistributionTotal = _rewardDistributionTotal.add(winningSubmissionData.rewardDistribution[i]);
    //     }

    //     winningSubmissionData.rewardDistributionTotal = _rewardDistributionTotal;

    //     // DoNothing and StartNextRound cases
    //     if(_selectWinnerAction == uint256(SelectWinnerAction.DoNothing) || _selectWinnerAction == uint256(SelectWinnerAction.StartNextRound))
    //     {
    //         for(uint256 j = 0; j < winningSubmissionData.winningSubmissions.length; j++)
    //         {
    //             // Calculate total reward denominator and store it somewhere when
    //             uint256 reward = winningSubmissionData.rewardDistribution[j].mul(10**18).div(winningSubmissionData.rewardDistributionTotal).mul(data.bounty).div(10**18);
    //             // Transfer the reward to the submission
    //             require(IMatryxToken(IMatryxPlatform(IMatryxTournament(IMatryxRound(this).getTournament()).getPlatform()).getTokenAddress()).transfer(winningSubmissionData.winningSubmissions[j], reward));
    //             IMatryxSubmission(winningSubmissionData.winningSubmissions[j]).addToWinnings(reward);
    //         }

    //         uint256 newBounty;

    //         if(IMatryxTournament(IMatryxRound(this).getTournament()).getBalance() < data.bounty)
    //         {
    //             newBounty = IMatryxTournament(IMatryxRound(this).getTournament()).getBalance();
    //         }
    //         else
    //         {
    //             newBounty = data.bounty;
    //         }

    //         LibConstruction.RoundData memory roundData;
    //         if(_selectWinnerAction == uint256(SelectWinnerAction.DoNothing))
    //         {
    //             roundData = LibConstruction.RoundData({
    //                 start: data.end.add(data.reviewPeriodDuration),
    //                 end: data.end.add(data.reviewPeriodDuration).add(data.end.sub(data.start)),
    //                 reviewPeriodDuration: data.reviewPeriodDuration,
    //                 bounty: data.bounty,
    //                 closed: false
    //             });
    //             IMatryxTournament(IMatryxRound(this).getTournament()).createRound(roundData, true);
    //         }
    //         else if(_selectWinnerAction == uint256(SelectWinnerAction.StartNextRound))
    //         {
    //             data.closed = true;
    //             roundData = LibConstruction.RoundData({
    //                 start: now,
    //                 end: _roundData.end,
    //                 reviewPeriodDuration: _roundData.reviewPeriodDuration,
    //                 bounty: _roundData.bounty,
    //                 closed: false
    //             });
    //             IMatryxTournament(IMatryxRound(this).getTournament()).createRound(roundData, false);
    //         }
    //     }
    //     else
    //     {
    //         // CloseTournament case
    //         data.closed = true;
    //     }
    // }
}
