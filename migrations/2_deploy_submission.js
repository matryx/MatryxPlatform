var MatryxPlatform = artifacts.require("./MatryxPlatform.sol");
var Tournament = artifacts.require("./Tournament.sol");
var Round = artifacts.require('./Round.sol');
var Submission = artifacts.require('./Submission.sol');

module.exports = function(deployer) {
	deployer.deploy(Submission, {gas: 1100000}).then(() => 
	{
		deployer.link(Submission, MatryxPlatform);
	});
};