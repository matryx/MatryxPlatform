pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxRouter.sol";

import "./MatryxPlatform.sol";

contract MatryxRound is MatryxRouter {
    constructor (uint256 _version, address _proxy) MatryxRouter(_version, _proxy) public {}
}

interface IMatryxRound {
    function getTournament() public view returns (address);
}

library LibRound {
    struct RoundTime {
        uint256 start;
        uint256 end;
        uint256 review;
    }

    struct RoundData {
        address tournament;
        RoundTime time;
        uint256 bounty;
        bool closed;
        address[] submissions;
    }

    function getTournament(address self, MatryxPlatform.Data storage data) public view returns (address) {
        return data.rounds[self].tournament;
    }
}
