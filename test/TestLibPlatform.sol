pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/IToken.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/MatryxPlatform.sol";
import "../contracts/LibPlatform.sol";
import "../contracts/LibTournament.sol";

contract TestLibPlatform {

    MatryxPlatform.Info info;

//  system
//  token
//  owner

    MatryxPlatform.Data data;

// uint256 totalBalance;                                                    // total allocated mtx balance of the platform
// mapping(address=>uint256) tournamentBalance;                             // maps tournament addresses to tournament balances
// mapping(bytes32=>uint256) commitBalance;                                 // maps commit hashes to commit mtx balances

// mapping(address=>LibTournament.TournamentData) tournaments;              // maps tournament addresses to tournament structs
// mapping(bytes32=>LibTournament.SubmissionData) submissions;              // maps submission identifier to submission struct

// address[] allTournaments;                                                // all matryx tournament addresses

// mapping(bytes32=>LibCommit.Commit) commits;                              // maps commit hashes to commits
// mapping(bytes32=>LibCommit.Group) groups;                                // maps group hashes to group structs
// mapping(bytes32=>bytes32) commitHashes;                                  // maps content hashes to commit hashes
// mapping(bytes32=>bytes32[]) commitToSubmissions;                         // maps commits to submission created from them
// mapping(bytes32=>LibCommit.CommitWithdrawalStats) commitWithdrawalStats; // maps commit hash to withdrawal stats

// bytes32[] initialCommits;                                                // all commits without parents
// mapping(bytes32=>uint256) commitClaims;                                  // timestamp of content hash claim

// mapping(address=>bool) whitelist;                                        // user whitelist
// mapping(address=>bool) blacklist;                                        // user blacklist

    
    function testGetInfo() public 
    {
        info.system = address(this);
        info.token = address(this);
        info.owner = address(this);

        MatryxPlatform.Info memory returnedInfo = LibPlatform.getInfo(address(this), address(this), info);
        Assert.equal(returnedInfo.system, address(this), "New system should be contract address");
        Assert.equal(returnedInfo.token, address(this), "New token should be contract address");
        Assert.equal(returnedInfo.owner, address(this), "New owner should be contract address");

        delete info.system;
        delete info.token;
        delete info.owner;
    }

    function testIsTournament() public
    {
        address tAddress = address(this);
        data.tournaments[tAddress].info.owner = address(this);
        bool isTournament = LibPlatform.isTournament(address(this), address(this), data, address(this));
        
        Assert.isTrue(isTournament, "Tournament should exist");

        delete data.tournaments[tAddress].info.owner;
    }

    function testIsCommit() public
    {
        bytes32 commitHash = bytes32(msg.sig);
        data.commits[commitHash].owner = address(this);
        bool isCommit = LibPlatform.isCommit(address(this), address(this), data, commitHash);
        
        Assert.isTrue(isCommit, "Commit should exist");

        delete data.commits[commitHash].owner;
    }

    function testIsSubmission() public
    {
        bytes32 submissionHash = bytes32(msg.sig);
        data.submissions[submissionHash].tournament = address(this);
        bool isSubmission = LibPlatform.isSubmission(address(this), address(this), data, submissionHash);
        
        Assert.isTrue(isSubmission, "Submission should exist");

        delete data.commits[submissionHash].owner;
    }

    function testGetTotalBalance() public
    {
        data.totalBalance = 50;
        uint256 balance = LibPlatform.getTotalBalance(address(this), address(this), data);
        
        Assert.equal(balance, 50, "Total balance should be 50");
        
        delete data.totalBalance;
    }

    function testGetTournamentCount() public
    {
        data.allTournaments.push(address(this));
        data.allTournaments.push(address(this));
        uint256 tournamentCount = LibPlatform.getTournamentCount(address(this), address(this), data);
        
        Assert.equal(tournamentCount, 2, "Should be two tournaments.");

        delete data.allTournaments;
    }

    function testGetTournaments() public
    {
        data.allTournaments.push(address(this));
        data.allTournaments.push(msg.sender);
        address[] memory tournaments = LibPlatform.getTournaments(address(this), address(this), data);

        Assert.equal(tournaments[0], address(this), "Returned tournaments incorrect.");
        Assert.equal(tournaments[1], msg.sender, "Returned tournaments incorrect.");

        delete data.allTournaments;
    }

    function testGetSubmission() public
    {
        LibTournament.SubmissionData memory submission;
        submission.tournament = address(this);
        submission.roundIndex = 0;
        submission.commitHash = bytes32(msg.sig);
        submission.content = "Qmtaco";
        submission.reward = 0;
        submission.timestamp = now;

        bytes32 submissionAddress = keccak256(abi.encodePacked(msg.sig));
        data.submissions[submissionAddress] = submission;

        LibTournament.SubmissionData memory returnedSubmission = LibPlatform.getSubmission(address(this), address(this), data, submissionAddress);
        Assert.equal(submission.tournament, returnedSubmission.tournament, "Submission's tournament is incorrect");
        Assert.equal(submission.roundIndex, returnedSubmission.roundIndex, "Submission's round index is incorrect");
        Assert.equal(submission.commitHash, returnedSubmission.commitHash, "Submission's commit hash is incorrect");
        Assert.equal(submission.content, returnedSubmission.content, "Submission's content is incorrect");
        Assert.equal(submission.reward, returnedSubmission.reward, "Submission's reward is incorrect");
        Assert.equal(submission.timestamp, returnedSubmission.timestamp, "Submission's timestamp is incorrect");

        delete data.submissions[submissionAddress];
    }

    function testBlacklist() public
    {
        info.owner = address(this);
        LibPlatform.blacklist(address(this), address(this), info, data, msg.sender);

        Assert.isTrue(data.blacklist[msg.sender], "Msg.sender should be on blacklist");
        
        delete data.blacklist[msg.sender];
    }

    uint256 version = 1;
    uint256 allowed = 50;
    function getVersion() public view returns (uint256)
    {
        return version;
    }
    function setContractType(address contractAddress, uint256 contractType) public view {}
    function allowance(address from, address to) public view returns (uint256) {
        return allowed;
    }
    function transferFrom(address from, address to, uint256 value) public view returns (bool) {
        return true;
    }

    function testCreateTournament() public
    {
        // allow user to use matryx
        data.whitelist[address(this)] = true;
        // bounty greater than 0
        LibTournament.TournamentDetails memory tDetails;
        tDetails.bounty = 50;
        // rount bounty less than or equal to tournament bounty
        LibTournament.RoundDetails memory rDetails;
        rDetails.bounty = 50;
        rDetails.duration = 2;
        // token allowance is greater than or equal to tournament balance
        info.token = address(this);
        info.system = address(this);

        address theTournament = LibPlatform.createTournament(address(this), address(this), info, data, tDetails, rDetails);
        Assert.equal(data.allTournaments.length, 1, "There should be exactly one tournament.");
        Assert.equal(data.tournaments[theTournament].info.version, 1, "Tournament version should be 1.");
        Assert.equal(data.tournaments[theTournament].info.owner, address(this), "Owner of tournament should be this");
        Assert.equal(data.tournaments[theTournament].details.bounty, 50, "Tournament bounty should be 50.");
        Assert.equal(data.totalBalance, 50, "Total balance of platform should be 50.");
        Assert.equal(data.tournamentBalance[theTournament], 50, "Tournament balance should be 50.");
        Assert.equal(data.tournaments[theTournament].rounds[0].details.bounty, 50, "Round bounty should be 50.");
        Assert.equal(data.tournaments[theTournament].rounds[0].details.duration, 2, "Round duration should be 2.");

        delete data.allTournaments;
        delete data.tournaments[theTournament].info.version;
        delete data.tournaments[theTournament].info.owner;
        delete data.tournaments[theTournament].details.bounty;
        delete data.totalBalance;
        delete data.tournamentBalance[theTournament];
        delete data.tournaments[theTournament].rounds[0].details.bounty;
        delete data.tournaments[theTournament].rounds[0].details.duration;
    }
}