pragma solidity ^0.4.18;

import "./MatryxOracleMessenger.sol";

contract MatryxPlatform is MatryxOracleMessenger
{

    struct Submission
    {
        uint256 tournamentId;
        uint256 id;

        string title;
        string body;
        string references;
        string contributors;
        address author;

        bool exists;
    }

    struct Tournament
    {
        uint256 id;

        string title;
        string description;
        uint256 bounty;

        mapping (uint256 => Submission) submissions;
        uint256[] submissionList;

        bool exists;
    }

    mapping (uint256 => Tournament) public tournaments;
    uint256[] public tournamentList;

    modifier owneronly()
    {
        require(msg.sender == owner);
        _;
    }

    function MatryxPlatform() public
    {
    }

    function prepareBalance(uint256 toIgnore) public
    {
        this.Query(bytes32(toIgnore), msg.sender);
    }

    function balanceIsNonZero() public view returns (bool)
    {
        uint balance = latestResponseFromOracle(msg.sender);
        bool nonZero = balance > 0x0;
        return nonZero;
    }

    function getBalance() public constant returns (uint256)
    {
        uint256 balance = latestResponseFromOracle(msg.sender);
        return balance;
    }

    function createTournament(string title, string description, uint256 bounty) owneronly public
    {
        Tournament memory newTournament;
        newTournament.id = tournamentCount() + 42;
        newTournament.title = title;
        newTournament.description = description;
        newTournament.bounty = bounty;
        newTournament.exists = true;
        tournaments[newTournament.id] = newTournament;
        tournamentList.push(newTournament.id);
    }

    function createSubmission(uint256 tournamentId, string title, string body, string references, string contributors) public
    {
        // Require tournament exists
        Tournament storage t = tournaments[tournamentId];
        require(t.exists);

        uint256 balanceMTX = latestResponseFromOracle(msg.sender);
        require(balanceMTX > 0);

        Submission memory newSubmission;
        newSubmission.tournamentId = tournamentId;
        newSubmission.id = submissionCount(tournamentId) + 42;
        newSubmission.title = title;
        newSubmission.body = body;
        newSubmission.references = references;
        newSubmission.contributors = contributors;
        newSubmission.author = msg.sender;
        newSubmission.exists = true;
        t.submissions[newSubmission.id] = newSubmission;
        t.submissionList.push(newSubmission.id);
    }

    function tournamentByIndex(uint256 idx) public constant returns (uint256, string, string, uint256)
    {
        require(tournamentCount() > idx);
        Tournament memory t = tournaments[tournamentList[idx]];
        require(t.exists);
        return (t.id, t.title, t.description, t.bounty);
    }

    function tournamentByAddress(uint256 tournamentId) public constant returns (uint256, string, string, uint256)
    {
        Tournament memory t = tournaments[tournamentId];
        require(t.exists);
        return (t.id, t.title, t.description, t.bounty);
    }

    function tournamentCount() public constant returns (uint256)
    {
        return tournamentList.length;
    }

    function submissionByIndex(uint256 tournamentId, uint256 idx) public constant returns (uint256, string, string, string, string, address)
    {
        require(submissionCount(tournamentId) > idx);
        Tournament storage t = tournaments[tournamentId];
        require(t.exists);
        Submission memory s = t.submissions[t.submissionList[idx]];
        require(s.exists);
        return (s.id, s.title, s.body, s.references, s.contributors, s.author);
    }

    function submissionByAddress(uint256 tournamentId, uint256 submissionId) public constant returns (uint256, string, string, string, string, address)
    {
        Tournament storage t = tournaments[tournamentId];
        require(t.exists);
        Submission memory s = t.submissions[submissionId];
        require(s.exists);
        return (s.id, s.title, s.body, s.references, s.contributors, s.author);
    }

    function submissionCount(uint256 tournamentId) public constant returns (uint256)
    {
        Tournament memory t = tournaments[tournamentId];
        require(t.exists);
        return t.submissionList.length;
    }

}
