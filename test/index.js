const CommonDAC = artifacts.require('CommonDAC');

contract('CommonDAC', accounts => {

  it('should initialize with a proposal', async () => {
    const contract = await CommonDAC.deployed();
    const proposalCount = await contract.proposalCount.call();
    assert.notEqual(proposalCount, 0, 'Initial proposal not present.');
  });

});
