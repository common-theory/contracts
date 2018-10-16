import React from 'react';
import ReactDOM from 'react-dom';
import { observable } from 'mobx';
import App from './App';
import Web3  from 'web3';

if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider);
} else {
  // Set the provider you want from Web3.providers
  web3 = new Web3(new Web3.providers.HttpProvider("http://192.168.1.200:8545"));
}

const AppState = observable({
  web3
});

ReactDOM.render(
  <App appState={AppState} />,
  document.getElementById('app')
);
