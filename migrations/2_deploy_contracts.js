const Syndicate = artifacts.require('Syndicate');
const Decision = artifacts.require('Decision');

/**
 * async/await and Promise.* functions do not work for the promises below
 * https://github.com/trufflesuite/truffle/issues/501#issuecomment-332589663
 **/
module.exports = function(deployer) {
  deployer.deploy(Syndicate)
    .then(() => deployer.deploy(Decision, Syndicate.address))
    .then(() => console.log(`
Deployed the following:

syndicate contract: ${Syndicate.address}
decision contract: ${Decision.address}
`));
};
