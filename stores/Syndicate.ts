import web3, { Contract } from 'web3';

interface ContractStore {
  contract: Contract;
}

export default class SyndicateStore implements ContractStore {
  contract: Contract;
  address: string;

  constructor(address: string) {
    const ABI = require('../Syndicate.abi.json');
    this.contract = new web3.eth.Contract(ABI, address);
  }

  async pay(receiver: string, weiValue: string, seconds: number, sender?: string) {
    const accounts = await web3.eth.getAccounts();
    if (!accounts.length) throw new Error('No available accounts');
    this.contract.methods.pay(receiver, weiValue, seconds, sender).send({
      from: accounts[0]
    });
  }
}
