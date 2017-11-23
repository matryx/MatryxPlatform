pragma solidity ^0.4.18;

import "./MatryxQueryEncrypter.sol";

// The actual part to be included in a client contract
contract MatryxOracleMessenger {

  // The original deployer of this contract (A Matryx private chain.
  // It is worth mentioning that neither this oracle nor this address 
  // will exist in the Mainnet version of Matryx. For now however,
  // Alpha Matryx needs this address and this class to ensure the 
  // initial security of users MTX balances. Our sincere and humbled
  // apologies. 
  address owner;

  // An event to let our node know that a new query has been performed.
  event QueryPerformed(uint256 id, address sender);

  // Map from user addresses to MatryxQueryEncrypters. We assume each user only
  // sends one query at a time.
  mapping(address => MatryxQueryEncrypter) internal queryEncrypters;
  // Map from user addresses (queriers) to QueryIDs. We assume each user only
  // makes one query at a time.
  mapping(address => uint256) internal fromQuerierToQueryID;
  // Map from QueryIDs to responses (bytes32s. aka dynamically-sized byte arrays.)
  mapping(uint256 => uint256) internal queryResponses;

  // Constructor for the Oracle (owner specified for Alpha Matryx)
  function MatryxOracleMessenger() public
  {
    owner = msg.sender;
  }

  // Requires that the platform owner (Nanome) is the sender
  // This is used to verify that we're the only ones acting as an oracle.
  modifier storerIsPlatformOwner()
  {
    require(msg.sender == owner);
    _;
  }

  function getOwner() public view returns (address _deployer)
  {
    return owner;
  }

  function latestResponseFromOracle(address _sender) internal view returns (uint256 _response)
  {
        uint256 queryID = fromQuerierToQueryID[_sender];
        uint256 response = queryResponses[queryID];
        return response;
  }

  // Uses [the user's existing]/[a new] QueryResolver,
  // depending on whether or not the user has submitted a query before.
  // Then, returns the queryID for the user to use in tracking the results
  // of their query.
  function Query(bytes32 _query, address _sender) external {
    MatryxQueryEncrypter encrypter;
    // If there's already a queryResolver for this user
    if(address(queryEncrypters[_sender]) > 0x0)
    {
        // Use that one.
        encrypter = queryEncrypters[_sender];
    }
    else
    {
        // Otherwise, create a new one and assign it.
        encrypter = new MatryxQueryEncrypter(_sender);
        queryEncrypters[_sender] = encrypter;
    }

    // Get the queryID from the QueryResolver.
    uint256 queryID = encrypter.query(_query);
    // Store that id under the sender's (querier's) address.
    fromQuerierToQueryID[_sender] = queryID;

    // Let our Alpha Matryx server know that a query has been performed!
    QueryPerformed(queryID, _sender);
  }

  // (Only to be used by MatryxPlatform, TinyOracle and MatryxQueryEncrypter.
  // This is not a user function.)
  // This function can be called (successfully) from Nanome's private chain
  function storeQueryResponse(uint256 _queryID,  uint256 _response) storerIsPlatformOwner public returns (bool success)
  {
      // Make sure:
      // 1) The response is not empty and
      // 2) There has not yet been a response created for this query
      if(_response > 0 && queryResponses[_queryID] == 0)
      {
          // If these conditions hold, we set the response here.
          queryResponses[_queryID] = _response;
          return true;
      }
      else
      {
        // Otherwise, we do nothing with the response,
        // and return false (unsuccessful storage of response).
        return false;
      }
  }
}