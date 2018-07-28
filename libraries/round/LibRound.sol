pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

import "../LibConstruction.sol";
import "../LibEnums.sol";
import "../math/SafeMath.sol";
import "../../interfaces/IMatryxToken.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../interfaces/IMatryxTournament.sol";
import "../../interfaces/IMatryxRound.sol";
import "../../interfaces/IMatryxSubmission.sol";

library LibRound
{
    using SafeMath for uint256;

    /// @dev Struct containting information about the submissions and entrants to a tournament
    ///        authorToSubmissionAddress: Mapping from the address of an author to their submissions
    ///        submissionExists: Bool indicating whether this address corresponds to an existing submission or not
    struct SubmissionAndEntrantTracking
    {
        mapping(address=>address[]) authorToSubmissionAddress;
        mapping(address=>bool) submissionExists;
    }

    /// @dev Struct information about the tournament submissions
    ///        submissions: Addresses of all the submisisons
    ///        submissionOwners: Addresses of all the owners of submissions
    struct SubmissionsData
    {
        address[] submissions;
        address[] submissionOwners;
    }

    /// @dev Struct containing winning submission information
    ///        winningSubmissions: Winning submission addresses
    ///        rewardDistribution: Distribution indicating how to split the reward among the submissions
    ///        selectWinnerAction: SelectWinnerAction (DoNothing, StartNextRound, CloseTournament) indicating what to do after winner selection
    ///        rewardDistributionTotal: Sum of all the reward distribution values
    struct SelectWinnersData
    {
        address[] winningSubmissions;
        uint256[] rewardDistribution;
        uint256 selectWinnerAction;
        uint256 rewardDistributionTotal;
    }

    /// @dev uint256 that has a flag associated - allows for uint256 to be a null value
    ///      exists: Whether or not the value is null/exists
    ///      value: Optional value for the uint256
    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    function getState(address platformAddress, LibConstruction.RoundData storage data, LibRound.SelectWinnersData storage winningSubmissionsData, LibRound.SubmissionsData storage submissionsData) public returns (uint256)
    {
        if(now < data.start)
        {
            return uint256(LibEnums.RoundState.NotYetOpen);
        }
        else if(now >= data.start && now < data.end)
        {
            if (IMatryxToken(IMatryxPlatform(platformAddress).getTokenAddress()).balanceOf(this) == 0)
            {
                return uint256(LibEnums.RoundState.Unfunded);
            }

            return uint256(LibEnums.RoundState.Open);
        }
        else if(now >= data.end && now < data.end.add(data.reviewPeriodDuration))
        {
            if(data.closed)
            {
                return uint256(LibEnums.RoundState.Closed);
            }
            else if(submissionsData.submissions.length == 0)
            {
                return uint256(LibEnums.RoundState.Abandoned);
            }
            else if(winningSubmissionsData.winningSubmissions.length > 0)
            {
                return uint256(LibEnums.RoundState.HasWinners);
            }

            return uint256(LibEnums.RoundState.InReview);
        }
        else if(winningSubmissionsData.winningSubmissions.length > 0)
        {
            return uint256(LibEnums.RoundState.Closed);
        }
        else
        {
            return uint256(LibEnums.RoundState.Abandoned);
        }
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

    function selectWinningSubmissions(LibConstruction.RoundData storage data, LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public
    {
        require(_selectWinnersData.winningSubmissions.length != 0);
        require(_selectWinnersData.winningSubmissions.length == _selectWinnersData.rewardDistribution.length);

        uint256 _rewardDistributionTotal;
        for(uint256 i = 0; i < _selectWinnersData.rewardDistribution.length; i++)
        {
            _rewardDistributionTotal = _rewardDistributionTotal.add(_selectWinnersData.rewardDistribution[i]);
        }
        _selectWinnersData.rewardDistributionTotal = _rewardDistributionTotal;

        // DoNothing and StartNextRound cases
        if(_selectWinnersData.selectWinnerAction == uint256(LibEnums.SelectWinnerAction.DoNothing) || _selectWinnersData.selectWinnerAction == uint256(LibEnums.SelectWinnerAction.StartNextRound))
        {
            for(uint256 j = 0; j < _selectWinnersData.winningSubmissions.length; j++)
            {
                // Calculate total reward denominator and store it somewhere when
                uint256 reward = _selectWinnersData.rewardDistribution[j].mul(10**18).div(_selectWinnersData.rewardDistributionTotal).mul(data.bounty).div(10**18);
                // Transfer the reward to the submission
                require(IMatryxToken(IMatryxPlatform(IMatryxTournament(IMatryxRound(this).getTournament()).getPlatform()).getTokenAddress()).transfer(_selectWinnersData.winningSubmissions[j], reward));
                IMatryxSubmission(_selectWinnersData.winningSubmissions[j]).addToWinnings(reward);
            }

            uint256 newBounty;

            if(IMatryxTournament(IMatryxRound(this).getTournament()).getBalance() < data.bounty)
            {
                newBounty = IMatryxTournament(IMatryxRound(this).getTournament()).getBalance();
            }
            else
            {
                newBounty = data.bounty;
            }

            LibConstruction.RoundData memory roundData;
            if(_selectWinnersData.selectWinnerAction == uint256(LibEnums.SelectWinnerAction.DoNothing))
            {
                roundData = LibConstruction.RoundData({
                    start: data.end.add(data.reviewPeriodDuration),
                    end: data.end.add(data.reviewPeriodDuration).add(data.end.sub(data.start)),
                    reviewPeriodDuration: data.reviewPeriodDuration,
                    bounty: data.bounty,
                    closed: false
                });
                IMatryxTournament(IMatryxRound(this).getTournament()).createRound(roundData, true);
            }
            else if(_selectWinnersData.selectWinnerAction == uint256(LibEnums.SelectWinnerAction.StartNextRound))
            {
                data.closed = true;
                roundData = LibConstruction.RoundData({
                    start: now,
                    end: _roundData.end,
                    reviewPeriodDuration: _roundData.reviewPeriodDuration,
                    bounty: _roundData.bounty,
                    closed: false
                });
                IMatryxTournament(IMatryxRound(this).getTournament()).createRound(roundData, false);
            }
        }
        else
        {
            // CloseTournament case
            data.closed = true;
        }
    }
}
