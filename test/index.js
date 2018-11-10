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

contract('CommonHosting', accounts => {

  it('should host a domain', async () => {
    const domain = 'commontheory.io';
    const contract = await CommonHosting.deployed();
    assert.equal(await contract.domainCount(), 0);
    await contract.storeDomain(domain, {
      from: accounts[0],
      // Buy 10 seconds of hosting time
      value: 10 * await contract.hostRate.call(),
      gasLimit: contract.storeDomain.estimateGas(domain)
    });

    assert.ok(await contract.isDomainHosted(domain));
    // Wait 20 seconds for the purchased hosting time to run out
    await new Promise((rs, rj) => setTimeout(rs, 20 * 1000));
    // Then make sure the hosting runs out
    assert.ok(!await contract.isDomainHosted(domain));
    assert.equal(await contract.domainCount(), 1);
  });

});
