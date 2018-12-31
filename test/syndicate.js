const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');

contract('Syndicate', accounts => {

  it('should initialize', async (...args) => {
    console.log(args);
    console.log(accounts);
    const contract = await Syndicate.deployed();
    assert.equal(true, true);
  });

  it('should deposit an instant payment', async () => {
    const contract = await Syndicate.deployed();
    const owner = accounts[0];
    await contract.deposit(owner, 0, {
      from: owner,
      value: 100,
      gasLimit: contract.deposit.estimateGas(owner, 0)
    });
    assert.equal(100, await contract.balances(owner));
  });

});
