pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxRouter.sol";

import "./MatryxProxy.sol";
import "./MatryxPlatform.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

contract MatryxTournament is MatryxRouter {
    constructor (uint256 _version, address _proxy) MatryxRouter(_version, _proxy) public {}
}

interface IMatryxTournament {
    function getOwner() public view returns (address);
    function getRounds() public view returns (address[]);
    function createRound(LibRound.RoundTime, uint256) public returns (address);
    function createSubmission(LibSubmission.SubmissionData) public returns (address);
}

library LibTournament {
    event RoundCreated(address _roundAddress);
    event SubmissionCreated(address _submissionAddress);

    struct TournamentData {
        address owner;
        address[] rounds;
    }

    function getOwner(address self, MatryxPlatform.Data storage data) public view returns (address) {
        return data.tournaments[self].owner;
    }

    function getRounds(address self, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.tournaments[self].rounds;
    }

    function createRound(address self, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundTime roundTime, uint256 bounty) public returns (address) {
        address roundAddress = new MatryxRound(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(roundAddress, MatryxProxy.ContractType.Round);
        data.allRounds.push(roundAddress);
        emit RoundCreated(roundAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        tournament.rounds.push(roundAddress);

        LibRound.RoundData storage round = data.rounds[roundAddress];
        round.tournament = self;
        round.time.start = roundTime.start;
        round.time.end = roundTime.end;
        round.time.review = roundTime.review;
        round.bounty = bounty;

        return roundAddress;
    }

    function createSubmission(address self, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibSubmission.SubmissionData submissionData) public returns (address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];

        address roundAddress = tournament.rounds[tournament.rounds.length - 1];
        LibRound.RoundData storage round = data.rounds[roundAddress];

        address submissionAddress = new MatryxSubmission(info.version, info.proxy);
        round.submissions.push(submissionAddress);

        LibSubmission.SubmissionData storage submission = data.submissions[submissionAddress];
        submission.tournament = self;
        submission.round = roundAddress;
        submission.title = submissionData.title;
        submission.descriptionHash = submissionData.descriptionHash;
        submission.fileHash = submissionData.fileHash;
        submission.timeSubmitted = now;
        submission.timeUpdated = now;

        emit SubmissionCreated(submissionAddress);
        return submissionAddress;
    }
}
