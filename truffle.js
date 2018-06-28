require('babel-register');
require('babel-polyfill');
require('babel-preset-env');
var fs = require('fs')
var path = require('path')
var mnemonic_path = path.join(__dirname, '..', 'keys', 'dev_wallet_mnemonic.txt')
var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic;

getFileContents = function(path) {
	return fs.readFileSync(path).toString();
}

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
	networks: 
	{
	  	development: 
	  	{
	  		host: "localhost",
	  		port: 8545,
	    	network_id: "*", // match any network
	     	gas: 6541593,
  			gasPrice: 30000000
		},
		ropsten:  {
     		provider: function() {
        		return new HDWalletProvider(getFileContents(mnemonic_path), "https://ropsten.infura.io/metamask")
     		},
     		network_id: 3,
     		gas:   6741593
		},
		testing:
		{
			host: "localhost",
	  		port: 8545,
	    	network_id: "*", // match any network
	     	gas: 6741593,
  			gasPrice: 30000000
		},
		coverage: 
		{
			host: "localhost",
			network_id: "*",
			port: 8545,     // <-- If you change this, also set the port option in .solcover.js.
			gas: 9000000000, // <-- Use this high gas value
			gasPrice: 100000     // <-- Use this low gas price
    	}
	},
	mocha: 
	{
        enableTimeouts: false
    },

	solc: 
	{
  		optimizer: 
  		{
	    	enabled: true,
	    	runs: 4000
  		}
  	}
};
