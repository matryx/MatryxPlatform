var MatryxQueryResolver = artifacts.require("./MatryxQueryResolver.sol");
var MatryxOracle = artifacts.require("./MatryxOracle.sol");
var MatryxPlatform = artifacts.require("./MatryxPlatform.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(MatryxPlatform);
};
