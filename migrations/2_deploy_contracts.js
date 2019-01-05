const Syndicate = artifacts.require('Syndicate');

/**
 * async/await and Promise.* functions do not work for the promises below
 * https://github.com/trufflesuite/truffle/issues/501#issuecomment-332589663
 **/
module.exports = function(deployer, _, accounts) {
  deployer.deploy(Syndicate)
    .then(() => console.log(`
Deployed the following:

syndicate contract: ${Syndicate.address}
`));
};
