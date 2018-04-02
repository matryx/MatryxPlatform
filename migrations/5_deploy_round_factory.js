var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");

var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
		deployer.link(SafeMath, MatryxRoundFactory);
		return deployer.deploy(MatryxRoundFactory, MatryxToken.address, MatryxSubmissionFactory.address);
};