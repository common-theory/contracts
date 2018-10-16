import Web3 from 'web3';
import { observable } from 'mobx';

if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider);
} else {
  // Set the provider you want from Web3.providers
  web3 = new Web3(new Web3.providers.HttpProvider("http://192.168.1.200:8545"));
}

/**
 * A singleton application store for passing contract state around
 **/
class AppStore {
  static _sharedInstance: AppStore;
  static get sharedInstance(): AppStore {
    if (this._sharedInstance) {
      return this._sharedInstance;
    }
    this._sharedInstance = new AppStore();
    return this._sharedInstance;
  }

  @observable public networkId: number = -1;

  async loadNetworkId() {
    this.networkId = await web3.eth.net.getId()
  }
}

export default AppStore.sharedInstance;
