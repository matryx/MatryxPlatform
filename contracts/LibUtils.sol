pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

library LibUtils {
    using SafeMath for uint256;

    function getSubArray(bytes32[] storage array, uint256 startIndex, uint256 count) public view returns (bytes32[]) {
        if (array.length == 0) return array;

        require(startIndex >= 0 && startIndex < array.length, "Index out of bounds");

        uint256 length = count;
        if (count <= 0 || startIndex.add(count) > array.length) {
            length = array.length.sub(startIndex);
        }

        bytes32[] memory subArray = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            subArray[i] = array[startIndex + i];
        }

        return subArray;
    }
}
