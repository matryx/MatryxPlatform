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
	    	gas: 5712388,
  			gasPrice: 21
		},
		coverage: 
		{
			host: "localhost",
			network_id: "*",
			port: 8545,         // <-- If you change this, also set the port option in .solcover.js.
			gas: 9000000000, // <-- Use this high gas value
			gasPrice: 10000000000     // <-- Use this low gas price
    	}
	}
};
