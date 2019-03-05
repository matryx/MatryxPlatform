pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MatryxPlatform.sol";
import "../contracts/LibPlatform.sol";
import "../contracts/LibTournament.sol";

contract TestLibTournament1 {

    MatryxPlatform.Info info;
    MatryxPlatform.Data data;

    bool transferHappened;
    uint256 transferAmount;
    function transfer(address to, uint256 value) public returns (bool)
    {
        transferHappened = true;
        transferAmount = value;
        return transferHappened;
    }
    function transferFrom(address from, address to, uint256 value) public view returns (bool)
    {
        return true;
    }

    function allowance(address owner, address spender) public returns (uint256)
    {
        return 1 ether;
    }

    function testGetInfo() public
    {
        data.tournaments[address(this)].info.version = 1;
        data.tournaments[address(this)].info.owner = address(this);
        LibTournament.TournamentInfo memory tInfo = LibTournament.getInfo(address(this), address(this), data);

        Assert.equal(tInfo.version, 1, "Tournament version incorrect.");
        Assert.equal(tInfo.owner, address(this), "Tournament owner incorrect.");

        delete data.tournaments[address(this)];
    }

    function testGetDetails() public
    {
        data.tournaments[address(this)].details.content = "Qmtaco";
        data.tournaments[address(this)].details.bounty = 5;
        data.tournaments[address(this)].details.entryFee = 2;

        LibTournament.TournamentDetails memory tDetails = LibTournament.getDetails(address(this), address(this), data);
        Assert.equal(tDetails.content, "Qmtaco", "Tournament content incorrect.");
        Assert.equal(tDetails.bounty, 5, "Tournament bounty incorrect.");
        Assert.equal(tDetails.entryFee, 2, "Tournament entryFee incorrect.");

        delete data.tournaments[address(this)];
    }

    function testGetBalance() public
    {
        data.tournamentBalance[address(this)] = 10;
        uint256 tBalance = LibTournament.getBalance(address(this), address(this), data);

        Assert.equal(tBalance, 10, "Tournament balance incorrect.");

        delete data.tournamentBalance[address(this)];
    }

    function testGetStateNotYetOpen() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now + 100;
        roundZero.details.duration = 1000;

        uint256 tState = LibTournament.getState(address(this), address(this), data);

        Assert.equal(tState, uint256(LibGlobals.TournamentState.NotYetOpen), "Tournament state should be NotYetOpen.");

        delete data.tournaments[address(this)];
    }

    function testGetStateOnHold() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 2;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 1;
        roundZero.info.closed = true;
        data.tournaments[address(this)].rounds[1].details.start = now + 60;
        data.tournaments[address(this)].rounds[1].details.duration = 1000;

        uint256 tState = LibTournament.getState(address(this), address(this), data);

        Assert.equal(tState, uint256(LibGlobals.TournamentState.OnHold), "Tournament state should be OnHold.");

        delete data.tournaments[address(this)];
    }

    function testGetStateOpen() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 1000;

        uint256 tState = LibTournament.getState(address(this), address(this), data);

        Assert.equal(tState, uint256(LibGlobals.TournamentState.Open), "Tournament state should be Open.");

        delete data.tournaments[address(this)];
    }

    function testGetStateClosed() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.info.closed = true;

        uint256 tState = LibTournament.getState(address(this), address(this), data);

        Assert.equal(tState, uint256(LibGlobals.TournamentState.Closed), "Tournament state should be Closed.");

        delete data.tournaments[address(this)];
    }

    function testGetStateAbandoned() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;

        uint256 tState = LibTournament.getState(address(this), address(this), data);

        Assert.equal(tState, uint256(LibGlobals.TournamentState.Abandoned), "Tournament state should be Abandoned.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateNotYetOpen() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now + 100;
        roundZero.details.duration = 1000;

        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.NotYetOpen), "Round state should be NotYetOpen.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateUnfunded() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;

        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.Unfunded), "Round state should be Unfunded.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateOpen() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;
        roundZero.details.bounty = 10;

        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.Open), "Round state should be Open.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateInReview() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.length = 1;
        roundZero.info.submissions[0] = keccak256(abi.encodePacked("submission"));

        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.InReview), "Round state should be InReview.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateHasWinners() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        bytes32 sHash = keccak256(abi.encodePacked("submission"));
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.push(sHash);
        roundZero.info.winners.submissions.push(sHash);
        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.HasWinners), "Round state should be HasWinners.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateClosed() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        bytes32 sHash = keccak256(abi.encodePacked("submission"));
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 121;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.push(sHash);
        roundZero.info.winners.submissions.push(sHash);
        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.Closed), "Round state should be Closed.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundStateAbandoned() public
    {
        // round setup
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 121;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        uint256 tState = LibTournament.getRoundState(address(this), address(this), data, 0);

        Assert.equal(tState, uint256(LibGlobals.RoundState.Abandoned), "Round state should be Abandoned.");

        delete data.tournaments[address(this)];
    }

    function testGetCurrentRoundIndex() public
    {
        // current round is Open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 60;
        roundZero.details.duration = 61;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;

        uint256 rIndex = LibTournament.getCurrentRoundIndex(address(this), address(this), data);
        Assert.equal(rIndex, 0, "Current round index should be 0");
    }

    function testGetRoundInfo() public
    {
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.info.submitterCount = 1;
        roundZero.info.closed = true;

        LibTournament.RoundInfo memory rInfo = LibTournament.getRoundInfo(address(this), address(this), data, 0);

        Assert.equal(rInfo.submitterCount, 1, "Submitter count should be 1.");
        Assert.equal(rInfo.closed, true, "Round should be closed.");

        delete data.tournaments[address(this)];
    }

    function testGetRoundDetails() public
    {
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = 1;
        roundZero.details.duration = 2;
        roundZero.details.review = 3;
        roundZero.details.bounty = 4;

        LibTournament.RoundDetails memory rDetails = LibTournament.getRoundDetails(address(this), address(this), data, 0);

        Assert.equal(rDetails.start, 1, "Round start should be 1.");
        Assert.equal(rDetails.duration, 2, "Round duration should be 2.");
        Assert.equal(rDetails.review, 3, "Round review should be 3.");
        Assert.equal(rDetails.bounty, 4, "Round bounty should be 4.");

        delete data.tournaments[address(this)];
    }

    function testGetSubmissionCount() public
    {
        data.tournaments[address(this)].rounds.length = 3;
        data.tournaments[address(this)].rounds[0].info.submissions.length = 1;
        data.tournaments[address(this)].rounds[1].info.submissions.length = 2;
        data.tournaments[address(this)].rounds[2].info.submissions.length = 3;

        uint256 submissionCount = LibTournament.getSubmissionCount(address(this), address(this), data);

        Assert.equal(submissionCount, 6, "Submission count should be 6");

        delete data.tournaments[address(this)];
    }

    function testGetEntryFeePaid() public
    {
        data.tournaments[address(this)].entryFeePaid[msg.sender].value = 100;
        uint256 entryFeePaid = LibTournament.getEntryFeePaid(address(this), address(this), data, msg.sender);

        Assert.equal(entryFeePaid, 100, "Entry fee should be 100.");

        delete data.tournaments[address(this)].entryFeePaid[msg.sender];
    }

    function testIsEntrant() public
    {
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;

        bool isEntrant = LibTournament.isEntrant(address(this), address(this), data, msg.sender);

        Assert.isTrue(isEntrant, "Sender should be entrant.");

        delete data.tournaments[address(this)].entryFeePaid[msg.sender];
    }

    function testEnter() public
    {
        // canEnterMatryx
        data.whitelist[msg.sender] = true;
        // tournament state open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 60;
        roundZero.details.duration = 1000;
        // token transfer
        info.token = address(this);
        // entry fee set
        data.tournaments[address(this)].details.entryFee = 5;
        data.tournaments[address(this)].totalEntryFees = 10;

        LibTournament.enter(address(this), msg.sender, info, data);

        Assert.equal(data.tournaments[address(this)].entryFeePaid[msg.sender].exists, true, "Entry fee should exist.");
        Assert.equal(data.tournaments[address(this)].entryFeePaid[msg.sender].value, 5, "Entry fee paid should be 5.");
        Assert.equal(data.tournaments[address(this)].totalEntryFees, 15, "Total entry fees paid should be 5.");
        Assert.equal(data.tournaments[address(this)].allEntrants[0], msg.sender, "Sender should be an entrant.");
        Assert.equal(data.totalBalance, 5, "Total platform balance should be 5.");

        delete data.whitelist[msg.sender];
        delete info.token;
        delete data.totalBalance;
        delete data.tournaments[address(this)].entryFeePaid[msg.sender];
        delete data.tournaments[address(this)];
    }

    function testExitWithEntryFee() public
    {
        // must be entrant
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;
        data.tournaments[address(this)].entryFeePaid[msg.sender].value = 5;
        data.tournaments[address(this)].totalEntryFees = 10;
        // platform total balance must be >= entry fee
        data.totalBalance = 10;

        LibTournament.exit(address(this), msg.sender, info, data);

        Assert.equal(data.tournaments[address(this)].totalEntryFees, 5, "Total entry fees should be 5.");
        Assert.isTrue(transferHappened, "Token transfer should have happened.");
        Assert.equal(data.tournaments[address(this)].entryFeePaid[msg.sender].exists, false, "Entry fee should not exist.");

        delete data.tournaments[address(this)].entryFeePaid[msg.sender].value;
        delete data.tournaments[address(this)];
        delete data.totalBalance;
        delete transferHappened;
    }

    function testExitNoEntryFee() public
    {
        // must be entrant
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;
        LibTournament.exit(address(this), msg.sender, info, data);

        Assert.equal(data.tournaments[address(this)].entryFeePaid[address(this)].exists, false, "Entry fee should not exist.");

        delete data.tournaments[address(this)].entryFeePaid[msg.sender];
    }

}