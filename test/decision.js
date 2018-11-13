const CommonDecision = artifacts.require('CommonDecision');
const CommonSyndicate = artifacts.require('CommonSyndicate');
const CommonHosting = artifacts.require('CommonHosting');
const assert = require('assert');

contract('CommonDecision', accounts => {

  it('should initialize with a proposal', async () => {
    const contract = await CommonDecision.deployed();
    const proposalCount = await contract.proposalCount.call();
    assert.notEqual(proposalCount, 0, 'Initial proposal not present.');
  });

});
