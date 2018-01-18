var MatryxPlatform = artifacts.require("./MatryxPlatform.sol");
var Tournament = artifacts.require("./Tournament.sol");
var Round = artifacts.require('./Round.sol');
var Submission = artifacts.require('./Submission.sol');

module.exports = function(deployer) {
	deployer.deploy(MatryxPlatform);
}