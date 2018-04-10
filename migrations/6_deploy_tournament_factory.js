var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxTournamentFactory);
	deployer.link(Strings, MatryxTournamentFactory);
	return deployer.deploy(MatryxTournamentFactory, MatryxToken.address, MatryxRoundFactory.address);
};