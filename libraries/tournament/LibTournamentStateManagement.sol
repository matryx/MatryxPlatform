pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../interfaces/IMatryxRound.sol";
import "../LibEnums.sol";

library LibTournamentStateManagement
{
    /// @dev uint256 that has a flag associated - allows for uint256 to be a null value
    ///      exists: Whether or not the value is null/exists
    ///      value: Optional value for the uint256
    struct uint256_optional
    {
        bool exists;
        uint256 value;
    }

    /// @dev State data for modifying and getting the state of a tournament
    ///      rounds: Array of round addresses associated with a tournament
    ///      isRound: Mapping of address to a boolean for round address checking
    ///      entryFeesTotal: uint256 of total entryfees collected by the tournament
    ///      roundBountyAllocation: uint256 of MTX allocated to a round
    ///      closed: Boolean value flagging whether the tournament is closed or not
    ///      hasBeenWithdrawnFrom: Boolean value flagging whether or not the tournament has been withdrawn from
    struct StateData
    {
        address[] rounds;
        mapping(address=>bool) isRound;
        uint256 entryFeesTotal;
        uint256 roundBountyAllocation;
        bool closed;
        bool hasBeenWithdrawnFrom;
    }

    /// @dev Entrant and submission data
    ///      hasWithdrawn: Whether or not a particular address has withdrawn from the tournament (while tournament is Abandoned)
    ///      numberOfSubmissions: Total number of submissions in the tournament
    ///      entrantToSubmissions: Mapping from an address of an entrant to their submissions
    ///      entrantToSubmissionToSubmissionIndex: Mapping from an entrant to a submission to its index
    ///      addressToEntryFeePaid: Whether or not this address has paid the tournament entry fee
    ///      numberOfEntrants: Total number of entrants in the tournament
    ///      winnersChosen: Whether or not winners have already been chosen for this round
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
            return uint256(LibEnums.TournamentState.Closed);
        }
        else if(numberOfRounds > 0)
        {
            uint256 roundState = IMatryxRound(roundAddress).getState();
            if(numberOfRounds != 1)
            {
                if(roundState == uint256(LibEnums.RoundState.Unfunded) || roundState == uint256(LibEnums.RoundState.Open) || roundState == uint256(LibEnums.RoundState.InReview)
                    || roundState == uint256(LibEnums.RoundState.HasWinners))
                {
                    return uint256(LibEnums.TournamentState.Open);
                }
                else if(roundState == uint256(LibEnums.RoundState.NotYetOpen))
                {
                    return uint256(LibEnums.TournamentState.OnHold);
                }
                else if(roundState == uint256(LibEnums.RoundState.Closed))
                {
                    return uint256(LibEnums.TournamentState.Closed);
                }
                else
                {
                    return uint256(LibEnums.TournamentState.Abandoned);
                }
            }
            else if(roundState == uint256(LibEnums.RoundState.NotYetOpen))
            {
                return uint256(LibEnums.TournamentState.NotYetOpen);
            }
            else if(roundState == uint256(LibEnums.RoundState.Unfunded) || roundState == uint256(LibEnums.RoundState.Open) || roundState == uint256(LibEnums.RoundState.InReview)
                    || roundState == uint256(LibEnums.RoundState.HasWinners))
            {
                return uint256(LibEnums.TournamentState.Open);
            }
            else if(roundState == uint256(LibEnums.RoundState.Closed))
            {
                return uint256(LibEnums.TournamentState.Closed);
            }
            else
            {
                return uint256(LibEnums.TournamentState.Abandoned);
            }
        }

        return 0;
    }

    /// @dev Returns the current round number.
    /// @return _currentRound Number of the current round.
    function currentRound(StateData storage stateData) public view returns (uint256 _currentRound, address _currentRoundAddress)
    {
        if(stateData.rounds.length > 1 &&
           IMatryxRound(stateData.rounds[stateData.rounds.length-2]).getState() == uint256(LibEnums.RoundState.HasWinners) &&
           IMatryxRound(stateData.rounds[stateData.rounds.length-1]).getState() == uint256(LibEnums.RoundState.NotYetOpen))
        {
            return (stateData.rounds.length-1, stateData.rounds[stateData.rounds.length-2]);
        }
        else
        {
            return (stateData.rounds.length, stateData.rounds[stateData.rounds.length-1]);
        }
    }

    ///@dev Returns the round that was created implicitly after selectWinners "DoNothing" option
    ///@return _ghostAddress Address of the upcoming round created during winner selection
    function getGhostRound(StateData storage stateData) internal view returns (uint256 _index, address _ghostAddress)
    {
        if(IMatryxRound(stateData.rounds[stateData.rounds.length-2]).getState() == uint256(LibEnums.RoundState.HasWinners) &&
           IMatryxRound(stateData.rounds[stateData.rounds.length-1]).getState() == uint256(LibEnums.RoundState.NotYetOpen))
        {
            return (stateData.rounds.length, stateData.rounds[stateData.rounds.length-1]);
        }

        return (0, address(0x0));
    }
}
