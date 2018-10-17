const CommonDAC = artifacts.require('CommonDAC');

module.exports = function(deployer) {
  deployer.deploy(CommonDAC, 'Chance Hudson', 'jchancehud', 'commontheory.io', '0xddeC6C333538fCD3de7cfB56D6beed7Fd8dEE604');
};
