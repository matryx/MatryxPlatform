pragma solidity ^0.4.21;

library LibIterable
{
    struct Bytes32ToAddressMapping
    {
        mapping(bytes32=>address) map;
        bytes32[] keys;
    }
}
