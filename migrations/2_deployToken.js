var MatryxToken = artifacts.require("MatryxToken");

module.exports = function(deployer) {
    return deployer.deploy(MatryxToken);
};