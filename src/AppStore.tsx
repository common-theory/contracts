import Web3 from 'web3';
import { observable, action } from 'mobx';

if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider);
} else {
  // Set the provider you want from Web3.providers
  web3 = new Web3(new Web3.providers.HttpProvider("http://192.168.1.200:8545"));
}

export default class AppStore {

  @observable networkId: number = -1;

  @action
  async loadNetworkId() {
    this.networkId = await web3.eth.net.getId();
  }
}
