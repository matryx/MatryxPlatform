const Migrations = artifacts.require('./Migrations.sol')

module.exports = function(deployer) {
  deployer.deploy(Migrations, { gas: 7e6, overwrite: false })
}