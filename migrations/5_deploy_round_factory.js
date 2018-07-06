// Private Chain MTX Address: 0x89c81164a847fae12841c7d2371864c7656f91c9
var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");
var matryxTokenAddress = "0x0c484097e2f000aadaef0450ab35aa00652481a1"

module.exports = function(deployer) {
		deployer.link(SafeMath, MatryxRoundFactory);
		return deployer.deploy(MatryxRoundFactory, matryxTokenAddress, MatryxSubmissionFactory.address).then((roundFactory) =>
        {
            return roundFactory.setContractAddress(web3.sha3("LibTournamentAdminMethods"), LibTournamentAdminMethods.address);
        });
};