pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../interfaces/IMatryxRound.sol";

library LibTournamentStateManagement
{    
    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }

    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    struct StateData
    {
        address[] rounds;
        mapping(address=>bool) isRound;
        uint256 entryFeesTotal;
        uint256 roundBountyAllocation;
        bool closed;
        bool hasBeenWithdrawnFrom;
    }

    struct EntryData
    {
        mapping(address=>bool) hasWithdrawn;
        uint256 numberOfSubmissions;
        mapping(address=>address[]) entrantToSubmissions;
        mapping(address=>mapping(address=>uint256_optional)) entrantToSubmissionToSubmissionIndex;
        mapping(address=>uint256_optional) addressToEntryFeePaid;
        uint256 numberOfEntrants;
        bool winnersChosen;
    }
    
    /// @dev Returns the state of the tournament.
    /// @return _state Current round's state : NotYetOpen, Open, Closed or Abandoned
    function getState(StateData storage stateData) public view returns (uint256 _state)
    {
        uint256 numberOfRounds;
        address roundAddress;
        (numberOfRounds, roundAddress) = currentRound(stateData);

        if(stateData.closed)
        {
            return uint256(TournamentState.Closed);
        }
        else if(numberOfRounds > 0)
        {
            uint256 roundState = IMatryxRound(roundAddress).getState();
            if(numberOfRounds != 1)
            {
                if(roundState == uint256(RoundState.Unfunded) || roundState == uint256(RoundState.Open) || roundState == uint256(RoundState.InReview)
                    || roundState == uint256(RoundState.HasWinners))
                {
                    return uint256(TournamentState.Open);
                }
                else if(roundState == uint256(RoundState.NotYetOpen))
                {
                    return uint256(TournamentState.OnHold);
                }
                else if(roundState == uint256(RoundState.Closed))
                {
                    return uint256(TournamentState.Closed);
                }
                else
                {
                    return uint256(TournamentState.Abandoned);
                }
            }
            else if(roundState == uint256(RoundState.NotYetOpen))
            {
                return uint256(TournamentState.NotYetOpen);
            }
            else if(roundState == uint256(RoundState.Unfunded) || roundState == uint256(RoundState.Open) || roundState == uint256(RoundState.InReview)
                    || roundState == uint256(RoundState.HasWinners))
            {
                return uint256(TournamentState.Open);
            }
            else if(roundState == uint256(RoundState.Closed))
            {
                return uint256(TournamentState.Closed);
            }
            else
            {
                return uint256(TournamentState.Abandoned);
            }
        }
        
        return 0;
    }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound(StateData storage stateData) public view returns (uint256 _currentRound, address _currentRoundAddress)
    {
        if(stateData.rounds.length > 1 && 
           IMatryxRound(stateData.rounds[stateData.rounds.length-2]).getState() == uint256(RoundState.HasWinners) &&
           IMatryxRound(stateData.rounds[stateData.rounds.length-1]).getState() == uint256(RoundState.NotYetOpen))
        {
            return (stateData.rounds.length-1, stateData.rounds[stateData.rounds.length-2]);
        }
        else
        {
            return (stateData.rounds.length, stateData.rounds[stateData.rounds.length-1]);
        }
    }

    ///@dev Returns the round that was created implicitly for the user after they chose the "DoNothing" option
    ///     when choosing their round winners.
    ///@return _ghostAddress Address of the upcoming round created during winner selection
    function getGhostRound(StateData storage stateData) internal returns (uint256 _index, address _ghostAddress)
    {
        if(IMatryxRound(stateData.rounds[stateData.rounds.length-2]).getState() == uint256(RoundState.HasWinners) &&
           IMatryxRound(stateData.rounds[stateData.rounds.length-1]).getState() == uint256(RoundState.NotYetOpen))
        {
            return (stateData.rounds.length-1, stateData.rounds[stateData.rounds.length-1]);
        }

        return (0, address(0x0));
    }
}