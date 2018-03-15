var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxPeerFactory);
	return deployer.deploy(MatryxPeerFactory);
};