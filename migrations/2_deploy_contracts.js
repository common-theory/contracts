const CommonDAC = artifacts.require('CommonDAC');

module.exports = function(deployer) {
  deployer.deploy(CommonDAC, 'Chance Hudson', 'jchancehud', 'commontheory.io');
};
