var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

var MatryxToken = artifacts.require("MatryxToken");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxTournamentFactory);
	deployer.link(Strings, MatryxTournamentFactory);
	return deployer.deploy(MatryxTournamentFactory, MatryxToken.address, MatryxRoundFactory.address).then(() =>
	{
		deployer.link(SafeMath, MatryxPeerFactory);
		return deployer.deploy(MatryxPeerFactory);
	});
};