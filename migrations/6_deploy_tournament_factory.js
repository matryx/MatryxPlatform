var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol");
var LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol");
var LibTournamentStateManagement = artifacts.require("../libraries/tournament/LibTournamentStateManagement.sol");
var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxTournamentFactory);
    deployer.link(Strings, MatryxTournamentFactory);
    deployer.link(LibTournamentStateManagement, MatryxTournamentFactory);
    deployer.link(LibTournamentAdminMethods, MatryxTournamentFactory);
    deployer.link(LibTournamentEntrantMethods, MatryxTournamentFactory);
    return deployer.deploy(MatryxTournamentFactory, MatryxToken.address, MatryxRoundFactory.address);
};