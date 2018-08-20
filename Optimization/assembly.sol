pragma solidity ^0.4.23;
// pragma experimental ABIEncoderV2;

import '../libraries/strings/strings.sol';
import '../libraries/math/SafeMath.sol';
import '../interfaces/IMatryxPlatform.sol';
import '../interfaces/IMatryxTournament.sol';
import '../interfaces/factories/IMatryxRoundFactory.sol';
import '../interfaces/IMatryxRound.sol';
import '../interfaces/IMatryxToken.sol';
import './Ownable.sol';

/// @title Tournament - The Matryx tournament.
/// @author Max Howard - <max@nanome.ai>, Sam Hessenauer - <sam@nanome.ai>
contract Assembly {
    using SafeMath for uint256;
    using strings for *;

    function addressLength(address[] _addrs) constant returns (uint256 res){
        assembly {
            //let x := mload(0x00)
            let x := mload(_addrs)
            res := x
        }
    }

    function determineAddressPartition(address[] _total, address[] _subset) constant returns (uint256 res) {
        uint256 all = addressLength(_total);
        uint256 sub = addressLength(_subset);
        res = all.sub(sub);
    }

    function getAddress(address[] _addr, uint _index) returns (address res) {
        assembly {
            //res := add(add(_data, 0x20), mul(i, 0x20))
            let x := mload(_addr) // Length of the address array
            let index := _index // Load from params (unneccesary?)
            res := sub(x,index) // position you must subtract from stack to get indexed data
        }
    }

    function createArray(uint a, uint b) constant returns (uint[]) {
        assembly {
            // Create an dynamic sized array manually.
            let memOffset := mload(0x40) // 0x40 is the address where next free memory slot is stored in Solidity.
            mstore(memOffset, 0x20) // single dimensional array, data offset is 0x20 (32 bytes)
            mstore(add(memOffset, 32), 2) // Set size to 2
            mstore(add(memOffset, 64), a) // array[0] = a
            mstore(add(memOffset, 96), b) // array[1] = b
            return(memOffset, 128)
        }
    }
}