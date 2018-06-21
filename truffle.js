require('babel-register');
require('babel-polyfill');
require('babel-preset-env');

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
