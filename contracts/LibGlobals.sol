pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

library LibGlobals {
    // optional uint256, to avoid default value being 0 messing things up
    struct o_uint256 {
        bool exists;
        uint256 value;
    }

    enum RoundState { NotYetOpen, Unfunded, Open, InReview, HasWinners, Closed, Abandoned }
    enum TournamentState { NotYetOpen, OnHold, Open, Closed, Abandoned}
    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }
}
