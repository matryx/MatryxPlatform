var Migrations = artifacts.require("./Migrations.sol");
var MatryxPlatformAlphaMain = artifacts.require("./MatryxPlatformAlphaMain.sol");
var Tournament = artifacts.require("./Tournament.sol");
var Submission = artifacts.require("./Submission.sol");



module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
