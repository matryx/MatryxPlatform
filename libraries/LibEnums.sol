pragma solidity ^0.4.24;

library LibEnums
{
    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
}
