const Delegate = artifacts.require('Delegate');
const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');
const BN = require('bn.js');

const DEFAULT_GAS = 300000;

/**
 * Delegate contract tests
 *
 * accounts[0] is the initial delegate
 **/
contract('Delegate', accounts => {

  /**
   * Tests the fallback payment function
   **/
  it('should accept payment', async () => {
    const _contract = await Delegate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
    await web3.eth.sendTransaction({
      from: owner,
      to: _contract.address,
      value: weiValue
    });
  });

  /**
   * Tests payment creation from Delegate contract
   **/
  it('should create payment', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await contract.methods.paymentCreate(weiValue, accounts[2], 100).send({
      from: accounts[0],
      gas: DEFAULT_GAS
    });
  });

  /**
   * Ensures failure from non-delegate
   **/
  it('non-delegate should fail to create payment', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await assert.rejects(contract.methods.paymentCreate(weiValue, accounts[2], 100).send({
      from: accounts[1],
      gas: DEFAULT_GAS
    }));
  });

  it('should fork payment', async () => {
    const _syndicate = await Syndicate.deployed();
    const syndicate = new web3.eth.Contract(_syndicate.abi, _syndicate.address);
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;

    // Send a payment to the delegate contract
    await syndicate.methods.paymentCreate(_contract.address, 100).send({
      from: accounts[1],
      value: weiValue,
      gas: DEFAULT_GAS
    });
    const paymentIndex = await syndicate.methods.paymentCount().call() - 1;
    await contract.methods.paymentFork(paymentIndex, accounts[2], weiValue / 2).send({
      from: accounts[0],
      gas: DEFAULT_GAS
    });
  });

  it('non-delegate should fail to fork payment', async () => {
    const _syndicate = await Syndicate.deployed();
    const syndicate = new web3.eth.Contract(_syndicate.abi, _syndicate.address);
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;

    // Send a payment to the delegate contract
    await syndicate.methods.paymentCreate(_contract.address, 100).send({
      from: accounts[1],
      value: weiValue,
      gas: DEFAULT_GAS
    });
    const paymentIndex = await syndicate.methods.paymentCount().call() - 1;
    await assert.rejects(contract.methods.paymentFork(paymentIndex, accounts[2], weiValue / 2).send({
      from: accounts[1],
      gas: DEFAULT_GAS
    }));
  });

  it('should withdraw', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await contract.methods.withdraw(10).send({
      from: accounts[0],
      gas: DEFAULT_GAS
    });
  });

  it('should fail to withdraw more than balance', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const balance = await web3.eth.getBalance(_contract.address) + 100;
    await assert.rejects(contract.methods.withdraw(balance).send({
      from: accounts[0],
      gas: DEFAULT_GAS
    }));
  });

  it('non-delegate should fail to withdraw', async () => {
    const _contract = await Delegate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 500;
    await web3.eth.sendTransaction({
      from: accounts[1],
      to: _contract.address,
      value: weiValue
    });
    await assert.rejects(contract.methods.withdraw(10).send({
      from: accounts[1],
      gas: DEFAULT_GAS
    }));
  });

});
