module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 3000000,
      gasPrice: 18000000000,
      from: '0x11f2915576dc51dffb246959258e8fe5a1913161'
    },
    test: {
      host: "localhost",
      port: 8545,
      network_id: "*", // match any network
      gas: 4712388,
      //from: "0x4ac11cb7ea279192354bed022491cac7eee62e7c"
    },
    prod: {
      host: '54.183.203.34',
      port: 4551,
      network_id: '*',
      from: '0x11f2915576dc51dffb246959258e8fe5a1913161'
    }
  }
};