const CommonHosting = artifacts.require('CommonHosting');

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
