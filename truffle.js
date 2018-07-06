require('babel-register');
require('babel-polyfill');
require('babel-preset-env');
var fs = require('fs')
var path = require('path')
var mnemonic_path = path.join(__dirname, '..', 'keys', 'dev_wallet_mnemonic.txt')
var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic;

// SETUP GLOBALS FOR CLI REPL
stringToBytes32 = require('./truffle/helper').stringToBytes32
getFileContents = path => fs.readFileSync(path).toString()

ethers = require('ethers')

// wallet key from ganache
wallet = new ethers.Wallet('0x' + 'f7d0ecaecde3010efb7ffc0b0efbf98619a1f960694d52836e38a43edd88c2a7')
wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')

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
