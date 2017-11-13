pragma solidity ^0.4.18;

import "./MatryxQueryResolver.sol";

// The actual part to be included in a client contract
contract MatryxOracle {

  // The original deployer of this contract (A Matryx private chain.
  // It is worth mentioning that neither this oracle nor this address 
  // will exist in the Mainnet version of Matryx. For now however,
  // Alpha Matryx needs this address and this class to ensure the 
  // initial security of users MTX balances. Our sincere and humbled
  // apologies. 
  address deployer;

  // An event to let our node know that a new query has been performed.
  event QueryPerformed(uint256 id);

  // Map from user addresses to MatryxQueryResolvers. We assume each user only
  // sends one query at a time.
  mapping(address => MatryxQueryResolver) private queryResolvers;
  // Map from user addresses (queriers) to QueryIDs. We assume each user only
  // makes one query at a time.
  mapping(address => uint256) private querierForQueryID;
  // Map from QueryIDs to responses (bytes32s. aka dynamically-sized byte arrays.)
  mapping(uint256 => bytes32) internal queryResponses;

  // Constructor for the Oracle (deployer specified for Alpha Matryx)
  function MatryxOracle() public
  {
    deployer = msg.sender;
  }

  // Requires that the platform deployer (Nanome) is the sender
  // This is used to verify that we're the only ones acting as an oracle.
  modifier submitterIsPlatformDeployer()
  {
    require(msg.sender == deployer);
    _;
  }

  function getDeployer() public view returns (address _deployer)
  {
    return deployer;
  }

  // Uses [the user's existing]/[a new] QueryResolver,
  // depending on whether or not the user has submitted a query before.
  // Then, returns the queryID for the user to use in tracking the results
  // of their query.
  function Query(bytes32 _query) external {
    MatryxQueryResolver resolver;
    // If there's already a queryResolver for this user
    if(address(queryResolvers[msg.sender]) > 0x0)
    {
        // Use that one.
        resolver = queryResolvers[msg.sender];
    }
    else
    {
        // Otherwise, create a new one and assign it.
        resolver = new MatryxQueryResolver(msg.sender);
        queryResolvers[msg.sender] = resolver;
    }

    // Get the queryID from the QueryResolver.
    uint256 queryID = resolver.query(_query);
    // Store that id under the sender's (querier's) address.
    querierForQueryID[msg.sender] = queryID;

    // Let our Alpha Matryx server know that a query has been performed!
    QueryPerformed(queryID);
  }

  // (Only to be used by MatryxPlatform, TinyOracle and MatryxQueryResolver.
  // This is not a user function.)
  // This function can be called (successfully) from Nanome's private chain
  function storeQueryResponse(uint256 _queryID, bytes32 _response) submitterIsPlatformDeployer external returns (bool success)
  {
      // Make sure:
      // 1) The response is not empty and
      // 2) There has not yet been a response created for this query
      if(_response > 0 && queryResponses[_queryID] == 0x0)
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