var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");

module.exports = function(deployer) {
	return deployer.deploy(MatryxToken);
};