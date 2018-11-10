const CommonSyndicate = artifacts.require('CommonSyndicate');
const CommonHosting = artifacts.require('CommonHosting');
const CommonDecision = artifacts.require('CommonDecision');
const StringUtils = artifacts.require('StringUtils');

/**
 * async/await and Promise.* functions do not work for the promises below
 * https://github.com/trufflesuite/truffle/issues/501#issuecomment-332589663
 **/
module.exports = function(deployer) {
  deployer.deploy(StringUtils)
    .then(() => deployer.link(StringUtils, CommonDecision))
    .then(() => deployer.link(StringUtils, CommonHosting))
    .then(() => deployer.deploy(CommonDecision, '0xAb027372B1c52e1615EDdeF59C3Ca4412bf63b9f', 30))
    .then(() => deployer.deploy(CommonSyndicate, CommonDecision.address))
    .then(() => deployer.deploy(CommonHosting, CommonDecision.address))
    .then(() => console.log(`
Deployed the following:

decision contract: ${CommonDecision.address}
syndicate contract: ${CommonSyndicate.address}
hosting contract: ${CommonHosting.address}
`));
};
