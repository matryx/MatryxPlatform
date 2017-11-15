module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 4551,
      network_id: "*", // Match any network id
      //gas: 2900000,
      //gasPrice: 18000000000
    },
    test: {
      host: "localhost",
      port: 8545,
      network_id: "*", // match any network
      gas: 4712388,
      //from: "0x4ac11cb7ea279192354bed022491cac7eee62e7c"
    }
  }
};