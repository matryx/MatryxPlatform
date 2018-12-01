const network = require('../truffle/network')
const MatryxToken = artifacts.require("MatryxToken")

module.exports = function(deployer) {
    if (network.network === "ganache") {
        return deployer.deploy(MatryxToken);
    }
    else {
        return Promise.resolve();
    }
};