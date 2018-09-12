var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol");
var LibRound = artifacts.require("../libraries/round/LibRound.sol");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");


module.exports = function (deployer) {
    deployer.link(SafeMath, MatryxRoundFactory);
    deployer.link(LibRound, MatryxRoundFactory);
    return deployer.deploy(MatryxRoundFactory, MatryxSubmissionFactory.address).then((roundFactory) => {
        return roundFactory.setContractAddress(web3.sha3("LibTournamentAdminMethods"), LibTournamentAdminMethods.address);
    });
};
