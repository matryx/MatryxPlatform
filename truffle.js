module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 4551,
      network_id: "*", // Match any network id
      gas: 2900000,
      gasPrice: 18000000000
    }
  }
};