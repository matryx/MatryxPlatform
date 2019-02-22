pragma solidity >=0.4.25 <0.6.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import { MatryxPlatform, LibPlatform } from "../contracts/MatryxPlatform.sol";

contract TestLibPlatform {

    MatryxPlatform.Info info;

//  system
//  token
//  owner

    MatryxPlatform.Data data;

//  uint256 totalBalance;                                        // total allocated mtx balance of the platform
//  mapping(address=>uint256) balanceOf;                         // maps user addresses to user balances
//  mapping(bytes32=>uint256) commitBalance;                     // maps commit hashes to commit mtx balances

//  mapping(address=>LibTournament.TournamentData) tournaments;  // maps tournament addresses to tournament structs
//  mapping(bytes32=>LibTournament.SubmissionData) submissions;  // maps submission identifier to submission struct

//  address[] allTournaments;                                    // all matryx tournament addresses

//  mapping(bytes32=>LibCommit.Commit) commits;                  // maps commit hashes to commits
//  mapping(bytes32=>LibCommit.Group) groups;                    // maps group hashes to group structs
//  mapping(bytes32=>bytes32) commitHashes;                      // maps content hashes to commit hashes
//  mapping(bytes32=>bytes32[]) commitToSubmissions;             // maps commits to submission created from them
//  mapping(bytes32=>LibCommit.CommitWithdrawalStats) commitWithdrawalStats; // maps commit hash to withdrawal stats

//  bytes32[] initialCommits;                                    // all commits without parents
//  mapping(bytes32=>uint256) commitClaims;                      // timestamp of content hash claim

//  mapping(address=>bool) whitelist;                            // user whitelist
//  mapping(address=>bool) blacklist;                            // user blacklist

    function testGetInfo() public 
    {
        info.system = address(this);
        info.token = address(this);
        info.owner = address(this);

        MatryxPlatform.Info memory info = LibPlatform.getInfo(address(this), address(this), info);
        // Assert.equal(info.system, address(this), "New system should be contract address");
        // Assert.equal(info.token, address(this), "New token should be contract address");
        // Assert.equal(info.owner, address(this), "New owner should be contract address");

        Assert.equal(uint256(0), uint256(0), "Rawr");

        info.system = address(0);
        info.token = address(0);
        info.owner = address(0);
    }

    function testGetTotalBalance() public
    {
        uint256 balance = LibPlatform.getTotalBalance(address(this), address(this), data);
        Assert.equal(balance, uint256(0), "Rawr");
    }
}

// function getInfo(address, address, LibPlatform.Info storage info) public view returns (LibPlatform.Info memory) {
// function isTournament(address, address, MatryxPlatform.Data storage data, address tAddress) public view returns (bool) {
// function getTotalBalance(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
// function getBalanceOf(address, address, MatryxPlatform.Data storage data, address cAddress) public view returns (uint256) {
// function getCommitBalance(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (uint256) {
// function getTournamentCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
// function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
// function getSubmission(address, address, MatryxPlatform.Data storage data, bytes32 submissionHash) external view returns (LibTournament.SubmissionData memory) {
// function withdrawBalance(address, address sender, LibPlatform.Info storage info, MatryxPlatform.Data storage data) public {
// function createTournament(address, address sender, LibPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails, LibTournament.RoundDetails memory rDetails) public returns (address) {