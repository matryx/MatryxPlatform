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
	    	gas: 4600000,
	    	from: "0xdf9c6a0024cd2db4db9fcf1207a63bda471caa8b"
		}
	}
};
