var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
// var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");

module.exports = function(deployer) {
	deployer.link(SafeMath, MatryxTournamentFactory);
        deployer.link(Strings, MatryxTournamentFactory);
            return deployer.deploy(MatryxTournamentFactory, "0xf35a0f92848bdfdb2250b60344e87b176b499a8f", MatryxRoundFactory.address);
	//deployer.link(Strings, MatryxTournamentFactory);
	//return deployer.deploy(MatryxTournamentFactory, MatryxToken.address, MatryxRoundFactory.address);
};