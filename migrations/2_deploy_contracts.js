//var MatryxQueryEncrypter = artifacts.require("./MatryxQueryEncrypter.sol");
//var MatryxOracleMessenger = artifacts.require("./MatryxOracleMessenger.sol");
var MatryxPlatform = artifacts.require("./MatryxPlatform.sol");

module.exports = function(deployer) {
  deployer.deploy(MatryxPlatform);
};
