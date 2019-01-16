var Migrations = artifacts.require('./Migrations.sol')

module.exports = function(deployer) {
  deployer.deploy(Migrations, { gasLimit: 8e6, overwrite: false })
}
