var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxTournamentFactory);
	deployer.link(Strings, MatryxTournamentFactory);
	return deployer.deploy(MatryxTournamentFactory, "0x89c81164a847fae12841c7d2371864c7656f91c9", MatryxRoundFactory.address);
};