pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MatryxPlatform.sol";
import "../contracts/LibPlatform.sol";
import "../contracts/LibTournament.sol";

contract TestLibTournament2 {

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

    function deleteTournament() internal
    {
        delete data.tournaments[address(this)];
    }

    function testCreateRound() public
    {
        data.tournamentBalance[address(this)] = 100;
        LibTournament.RoundDetails memory rDetails;
        rDetails.start = 0;
        rDetails.duration = 100;
        rDetails.review = 100;
        rDetails.bounty = 50;

        LibTournament.createRound(address(this), address(this), info, data, rDetails);

        Assert.equal(data.tournaments[address(this)].rounds.length, 1, "Should be one round");
        
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        Assert.equal(roundZero.details.start, now, "Start should be now.");
        Assert.equal(roundZero.details.duration, 100, "Round duration should be 100.");
        Assert.equal(roundZero.details.review, 100, "Round review should be 100.");
        Assert.equal(roundZero.details.bounty, 50, "Round bounty should be 50.");

        deleteTournament();
    }

    function testCreateSubmission() public
    {
        // sender can use matryx
        data.whitelist[msg.sender] = true;
        // tournament entry fee paid
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;
        // commit has owner
        bytes32 commitHash = keccak256("commit");
        data.commits[commitHash].owner = msg.sender;
        // current round is Open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;
        roundZero.details.bounty = 10;

        LibTournament.createSubmission(address(this), msg.sender, info, data, "QmSubmissionStuff", commitHash);

        bytes32 submissionHash = keccak256(abi.encodePacked(address(this), commitHash, uint256(0)));
        
        Assert.equal(data.commitToSubmissions[commitHash][0], submissionHash, "Commit hash should be linked to submission hash.");
        Assert.equal(roundZero.info.submissions[0], submissionHash, "Submission should be in round's submissions array.");
        Assert.isTrue(roundZero.hasSubmitted[msg.sender], "hasSubmitted flag should be true for sender.");
        Assert.equal(roundZero.info.submitterCount, 1, "Round should have 1 submitter.");

        deleteTournament();
        delete data.commitToSubmissions[commitHash];
        delete data.commits[commitHash];
    }

    function testUpdateDetails() public
    {
        data.tournaments[address(this)].info.owner = msg.sender;

        LibTournament.TournamentDetails memory tDetails;
        tDetails.content = "QmTournamentDetails";
        tDetails.entryFee = 10;

        LibTournament.updateDetails(address(this), msg.sender, data, tDetails);

        Assert.equal(data.tournaments[address(this)].details.content, tDetails.content, "Tournament content incorrect.");
        Assert.equal(data.tournaments[address(this)].details.entryFee, tDetails.entryFee, "Tournament entryFee incorrect.");

        delete data.tournaments[address(this)].details;
    }

    function testAddToBounty() public
    {
        // set token
        info.token = address(this);
        // current round is Open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;
        roundZero.details.bounty = 10;
        // total balance is 10
        data.totalBalance = 10;
        // tournamentBalance is 10
        data.tournamentBalance[address(this)] = 10;
        data.tournaments[address(this)].details.bounty = 10;

        LibTournament.addToBounty(address(this), msg.sender, info, data, 10);
        
        Assert.equal(data.totalBalance, 20, "Total platform balance should be 20.");
        Assert.equal(data.tournamentBalance[address(this)], 20, "Tournament balance should increase.");
        Assert.equal(data.tournaments[address(this)].details.bounty, 20, "Tournament bounty should be 20.");

        deleteTournament();
        delete data.totalBalance;
        delete data.tournamentBalance[address(this)];
    }

    function testTransferToRound() public
    {
        // Must be owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // current round is Open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 1;
        roundZero.details.duration = 61;
        roundZero.details.bounty = 10;
        // total balance is 10
        data.totalBalance = 20;

        data.tournamentBalance[address(this)] = 20;

        LibTournament.transferToRound(address(this), msg.sender, data, 10);

        Assert.equal(roundZero.details.bounty, 20, "Round bounty should be 20.");

        deleteTournament();
        delete data.totalBalance;
        delete data.tournamentBalance[address(this)];
    }

    function testSelectWinnersDoNothing() public
    {
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // create wData
        bytes32 winner = keccak256("winner");
        bytes32 commitHash = keccak256("commit");
        LibTournament.WinnersData memory wData;
        bytes32[] memory subs = new bytes32[](1);
        subs[0] = winner;
        uint256[] memory dist = new uint256[](1);
        dist[0] = 1;
        wData.submissions = subs;
        wData.distribution = dist;
        // create rDetails
        LibTournament.RoundDetails memory rDetails;
        // current round is in review
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.length = 1;
        roundZero.info.submissions[0] = winner;

        // submission must exist on platform
        data.submissions[winner].tournament = address(this);
        data.submissions[winner].commitHash = commitHash;

        LibTournament.selectWinners(address(this), msg.sender, info, data, wData, rDetails);

        Assert.equal(roundZero.info.winners.submissions[0], winner, "First round winner incorrect.");
        Assert.equal(data.submissions[winner].reward, 10, "Full bounty not awarded to sole round winner.");
        Assert.equal(data.commitBalance[commitHash], 10, "Full bounty not allocated to sole round winner's commit.");
        Assert.equal(data.tournamentBalance[address(this)], 10, "Tournament balance should have decreased to 10.");
        
        delete data.tournamentBalance[address(this)];
        deleteTournament();
        delete data.submissions[winner];
        delete data.commitBalance[commitHash];
    }

    function testSelectWinnersStartNextRound() public
    {
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // create wData
        bytes32 winner = keccak256("winner");
        bytes32 commitHash = keccak256("commit");
        LibTournament.WinnersData memory wData;
        bytes32[] memory subs = new bytes32[](1);
        subs[0] = winner;
        uint256[] memory dist = new uint256[](1);
        dist[0] = 1;
        wData.submissions = subs;
        wData.distribution = dist;
        wData.action = 1;
        // create rDetails
        LibTournament.RoundDetails memory rDetails;
        rDetails.duration = 60;
        rDetails.bounty = 10;
        // current round is in review
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.length = 1;
        roundZero.info.submissions[0] = winner;

        // submission must exist on platform
        data.submissions[winner].tournament = address(this);
        data.submissions[winner].commitHash = commitHash;

        LibTournament.selectWinners(address(this), msg.sender, info, data, wData, rDetails);

        Assert.equal(roundZero.info.winners.submissions[0], winner, "First round winner incorrect.");
        Assert.equal(data.submissions[winner].reward, 10, "Full bounty not awarded to sole round winner.");
        Assert.equal(data.commitBalance[commitHash], 10, "Full bounty not allocated to sole round winner's commit.");
        Assert.equal(data.tournamentBalance[address(this)], 10, "Tournament balance should have decreased to 10.");
        Assert.isTrue(roundZero.info.closed, "Old round is closed");
        Assert.equal(data.tournaments[address(this)].rounds[1].details.duration, 60, "New round duration is incorrect.");
        Assert.equal(data.tournaments[address(this)].rounds[1].details.bounty, 10, "New round bounty is incorrect.");

        delete data.tournamentBalance[address(this)];
        deleteTournament();
        delete data.submissions[winner];
        delete data.commitBalance[commitHash];
    }

    function testSelectWinnersCloseTournament() public
    {
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // create wData
        bytes32 winner = keccak256("winner");
        bytes32 commitHash = keccak256("commit");
        LibTournament.WinnersData memory wData;
        bytes32[] memory subs = new bytes32[](1);
        subs[0] = winner;
        uint256[] memory dist = new uint256[](1);
        dist[0] = 1;
        wData.submissions = subs;
        wData.distribution = dist;
        wData.action = 2;
        // create rDetails
        LibTournament.RoundDetails memory rDetails;
        rDetails.duration = 60;
        rDetails.bounty = 10;
        // current round is InReview
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.length = 1;
        roundZero.info.submissions[0] = winner;

        // submission must exist on platform
        data.submissions[winner].tournament = address(this);
        data.submissions[winner].commitHash = commitHash;

        Assert.equal(data.submissions[winner].reward, 0, "Reward for submission should be 0 initially.");

        LibTournament.selectWinners(address(this), msg.sender, info, data, wData, rDetails);

        Assert.equal(roundZero.info.winners.submissions[0], winner, "First round winner incorrect.");
        Assert.equal(data.submissions[winner].reward, 20, "Full bounty not awarded to sole round winner.");
        Assert.equal(data.commitBalance[commitHash], 20, "Full bounty not allocated to sole round winner's commit.");
        Assert.equal(data.tournamentBalance[address(this)], 0, "Tournament balance should have been depleted.");
        Assert.isTrue(roundZero.info.closed, "Old round is closed");
        Assert.equal(roundZero.details.bounty, 20, "Last round bounty not remaining tournament balance.");
        Assert.equal(data.tournaments[address(this)].rounds.length, 1, "Total number of rounds incorrect.");

        delete data.tournamentBalance[address(this)];
        deleteTournament();
        delete data.submissions[winner];
        delete data.commitBalance[commitHash];
    }

    function testUpdateNextRound() public
    {
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // round not yet open
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now + 60;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;

        LibTournament.RoundDetails memory rDetails;
        rDetails.start = now;
        rDetails.duration  = 40;
        rDetails.review = 30;
        rDetails.bounty = 20;

        LibTournament.updateNextRound(address(this), msg.sender, data, rDetails);

        Assert.equal(roundZero.details.start, now, "Round should be starting now.");
        Assert.equal(roundZero.details.duration, 40, "Round duration should be 40.");
        Assert.equal(roundZero.details.review, 30, "Round review should be 30.");
        Assert.equal(roundZero.details.bounty, 20, "Round bounty should be 20.");

        delete data.tournamentBalance[address(this)];
        deleteTournament();
    }

    function testStartNextRound() public
    {
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        
        // round setup, first HasWinners, second is OnHold
        data.tournaments[address(this)].rounds.length = 2;

        bytes32 sHash = keccak256(abi.encodePacked("submission"));
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.push(sHash);
        roundZero.info.winners.submissions.push(sHash);
        data.tournaments[address(this)].rounds[1].details.start = now + 60;
        data.tournaments[address(this)].rounds[1].details.duration = 1000;

        LibTournament.startNextRound(address(this), msg.sender, data);

        Assert.isTrue(roundZero.info.closed, "Round 0 should be closed.");
        Assert.equal(data.tournaments[address(this)].rounds[1].details.start, now, "Round 1 should start now.");

        delete data.tournamentBalance[address(this)];
        deleteTournament();
    }

    function testWithdrawFromAbandoned() public
    {
        // set token
        info.token = address(this);
        // set total balance
        data.totalBalance = 20;
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // current round is Abandoned
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;
        roundZero.details.bounty = 10;
        // sender and someone else have submitted to round
        roundZero.hasSubmitted[msg.sender] = true;
        roundZero.hasSubmitted[address(uint256(msg.sender) + 1)] = true;
        roundZero.info.submitterCount = 2;
        // sender must be entrant to exit
        data.tournaments[address(this)].entryFeePaid[msg.sender].exists = true;

        LibTournament.withdrawFromAbandoned(address(this), msg.sender, info, data);

        Assert.isTrue(roundZero.info.closed, "Round should have closed.");
        Assert.isTrue(data.tournaments[address(this)].hasWithdrawn[msg.sender], "Sender should have withdrawn.");
        Assert.equal(data.tournaments[address(this)].numWithdrawn, 1, "Number of users who've withdrawn should be 1.");
        Assert.equal(data.totalBalance, 10, "Total balance should have halfed to 10.");
        Assert.equal(data.tournamentBalance[address(this)], 10, "Tournament balance should have halfed to 10.");
        Assert.isTrue(transferHappened, "Transfer should have happened.");
        Assert.equal(transferAmount, 10, "Transfer amount should have been 10.");

        delete info.token;
        delete data.totalBalance;
        delete data.tournamentBalance[address(this)];
        roundZero.hasSubmitted[address(uint256(msg.sender) + 1)] = false;
        roundZero.hasSubmitted[msg.sender] = false;
        deleteTournament();
        delete transferHappened;
        delete transferAmount;
    }

    function testCloseTournament() public
    {
        // set total balance
        data.totalBalance = 20;
        // set tournament balance
        data.tournamentBalance[address(this)] = 10;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;

        // create wData
        bytes32 winner = keccak256("winner");
        bytes32 commitHash = keccak256("commit");
        LibTournament.WinnersData memory wData;
        bytes32[] memory subs = new bytes32[](1);
        subs[0] = winner;
        uint256[] memory dist = new uint256[](1);
        dist[0] = 1;
        wData.submissions = subs;
        wData.distribution = dist;

        // round setup, first is closed, second HasWinners, third is ghost
        data.tournaments[address(this)].rounds.length = 3;
        
        bytes32 sHash = keccak256(abi.encodePacked("submission"));
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 182;
        roundZero.details.duration = 60;
        roundZero.details.review = 61;
        roundZero.details.bounty = 10;
        roundZero.info.submissions.push(sHash);
        roundZero.info.winners = wData;
        roundZero.info.closed = true;
        // submission won first round
        data.submissions[winner].reward = 10;
        data.commitBalance[commitHash] = 10;

        LibTournament.RoundData storage roundOne = data.tournaments[address(this)].rounds[1];
        roundOne.details.start = now - 61;
        roundOne.details.duration = 60;
        roundOne.details.review = 60;
        roundOne.details.bounty = 10;
        roundOne.info.submissions.push(sHash);
        roundOne.info.winners = wData;

        LibTournament.RoundData storage roundTwo = data.tournaments[address(this)].rounds[2];
        roundTwo.details.start = roundOne.details.start + roundOne.details.duration + roundOne.details.review;
        roundTwo.details.duration = 60;
        roundTwo.details.review = 60;

        // submission must exist on platform
        data.submissions[winner].tournament = address(this);
        data.submissions[winner].commitHash = commitHash;

        uint256 currentRound = LibTournament.getCurrentRoundIndex(address(this), msg.sender, data);
        uint256 currentState = LibTournament.getRoundState(address(this), msg.sender, data, 1);

        LibTournament.closeTournament(address(this), msg.sender, data);

        Assert.equal(data.commitBalance[commitHash], 20, "Commit balance should be 20.");
        Assert.equal(data.submissions[winner].reward, 20, "Submission reward should be 20.");
        Assert.equal(data.tournamentBalance[address(this)], 0, "Tournament balance should be 0.");
        Assert.equal(data.tournaments[address(this)].rounds.length, 2, "Ghost round should be gone.");

        delete data.totalBalance;
        delete data.tournamentBalance[address(this)];
        deleteTournament();
        delete data.submissions[winner];
        delete data.commitBalance[commitHash];
    }

    function testRecoverBounty() public
    {
        // set token
        info.token = address(this);
        // set total balance
        data.totalBalance = 20;
        // set tournament balance
        data.tournamentBalance[address(this)] = 20;
        // set tournament owner
        data.tournaments[address(this)].info.owner = msg.sender;
        // current round Abandoned
        data.tournaments[address(this)].rounds.length = 1;
        LibTournament.RoundData storage roundZero = data.tournaments[address(this)].rounds[0];
        roundZero.details.start = now - 61;
        roundZero.details.duration = 60;
        roundZero.details.review = 60;

        LibTournament.recoverBounty(address(this), msg.sender, info, data);

        Assert.isTrue(roundZero.info.closed, "Round should have closed.");
        Assert.equal(data.tournaments[address(this)].numWithdrawn, 1, "Number of users who've withdrawn should be 1.");
        Assert.isZero(data.totalBalance, "Total balance should be 0.");
        Assert.isZero(data.tournamentBalance[address(this)], "Tournament balance should be 0.");
        Assert.isTrue(transferHappened, "Token transfer should have happen.");
        Assert.equal(transferAmount, 20, "Transfer amount should be 20.");

        delete info.token;
        delete data.totalBalance;
        delete data.tournamentBalance[address(this)];
        deleteTournament();
    }
}