const Migrations = artifacts.require('./Migrations.sol')

module.exports = function(deployer) {
  deployer.deploy(Migrations, { gas: 8e6, overwrite: false })
}
