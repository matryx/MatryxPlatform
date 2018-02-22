var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

var MatryxToken = artifacts.require("MatryxToken");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
	return deployer.deploy(MatryxPlatform, MatryxToken.address, MatryxPeerFactory.address, MatryxTournamentFactory.address);
}