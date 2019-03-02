pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../MatryxSystem.sol";
import "../MatryxPlatform.sol";
import "../MatryxTournament.sol";
import "./LibTournament2.sol";

interface IPlatform2 {
    function getTwo() external pure returns (uint256);
    function isTournament(address) external view returns (bool);
    function getTournamentCount() external pure returns (uint256);
    function createTournament() external returns (address);
    function getTournaments() external pure returns (address[] memory);
}

library LibPlatform2 {
    function getTwo(address, address, MatryxPlatform.Info storage) public pure returns (uint256 number) {
        return 2;
    }

    function getTournamentCount(address, address, MatryxPlatform.Data storage) public pure returns (uint256 count) {
        return 99000000000000000000;
    }

    function isTournament(address, address, MatryxPlatform.Data storage data, address tAddress) public view returns (bool) {
        return data.tournaments[tAddress].info.owner != address(0);
    }

    function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allTournaments;
    }

    function createTournament(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public returns (address) {
        uint256 version = IMatryxSystem(info.system).getVersion();
        address tAddress = address(new MatryxTournament(version, info.system));

        IMatryxSystem(info.system).setContractType(tAddress, uint256(LibSystem.ContractType.Tournament));
        data.allTournaments.push(tAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.info.version = version;
        tournament.info.owner = sender;

        data.totalBalance = data.totalBalance + 12345;
        data.tournamentBalance[tAddress] = 12345;

        LibTournament2.createRound(tAddress, address(this), info, data);

        return tAddress;
    }

}