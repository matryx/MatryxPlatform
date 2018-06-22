var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
// var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
		deployer.link(SafeMath, MatryxRoundFactory);
		return deployer.deploy(MatryxRoundFactory, "0xf35a0f92848bdfdb2250b60344e87b176b499a8f", MatryxSubmissionFactory.address);
};

// 0x89c81164a847fae12841c7d2371864c7656f91c9