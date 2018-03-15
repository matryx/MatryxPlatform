var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
		deployer.link(SafeMath, MatryxRoundFactory);
		return deployer.deploy(MatryxRoundFactory, "0x89c81164a847fae12841c7d2371864c7656f91c9", MatryxSubmissionFactory.address);
};