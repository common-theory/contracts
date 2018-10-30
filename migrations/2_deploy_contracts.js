const CommonDAC = artifacts.require('CommonDAC');

module.exports = function(deployer) {
  deployer.deploy(CommonDAC, '0xAb027372B1c52e1615EDdeF59C3Ca4412bf63b9f');
};
