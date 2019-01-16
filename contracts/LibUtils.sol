pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

library LibUtils {
    using SafeMath for uint256;

    /// @dev Returns subarray
    /// @param array  Array to get subarray of
    /// @param index  Index to start at
    /// @param count  Number elements to return
    /// @return       Returns a subarray of array with count elements starting at index
    function getSubArray(bytes32[] storage array, uint256 index, uint256 count) public view returns (bytes32[] memory) {
        if (array.length == 0) return array;

        require(index >= 0 && index < array.length, "Index out of bounds");

        uint256 length = count;
        if (count <= 0 || index.add(count) > array.length) {
            length = array.length.sub(index);
        }

        bytes32[] memory subArray = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            subArray[i] = array[index + i];
        }

        return subArray;
    }

    /// @dev Removes array element and replaces with last element
    /// @param array  Array to remove from
    /// @param index  Element to remove
    function removeArrayElement(bytes32[] storage array, uint256 index) public {
        require(index < array.length, "Index out of bounds");

        if (index < array.length - 1) {
            array[index] = array[array.length - 1];
        }

        array.length = array.length - 1;
    }
}
