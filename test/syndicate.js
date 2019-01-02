const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');

contract('Syndicate', accounts => {

  it('should instant deposit', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 0;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const balance = await contract.methods.balances(owner).call();
    assert.equal(weiValue.toString(), balance.toString());
  });

  it('should instant deposit via fallback', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
    await web3.eth.sendTransaction({
      from: owner,
      to: _contract.address,
      value: weiValue,
      gas: 300000
    });
    const balance = await contract.methods.balances(owner).call();
    assert.equal(weiValue.toString(), balance.toString());
  });

  it('should deposit over time', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 500;
    const time = 100;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    const payment = await contract.methods.payments(paymentIndex).call();
    do {
      await contract.methods.paymentSettle(paymentIndex).send({
        from: owner,
        gas: 300000
      });
      const _payment = await contract.methods.payments(paymentIndex).call();
      const now = new Date() / 1000;
      const totalWeiOwed = +payment.weiValue * Math.min(now - +payment.timestamp, +payment.time) / +payment.time;
      assert.ok(+_payment.weiPaid <= totalWeiOwed);
      console.log(`weiPaid: ${_payment.weiPaid} of ${_payment.weiValue}`);
      if (payment.weiValue === _payment.weiPaid) break;
      if (now >= payment.timestamp + 30) throw new Error('Payment not resolved in the correct amount of time');
    } while (true);
  });

});
