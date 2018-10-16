import React from 'react';
import ReactDOM from 'react-dom';
import { observable } from 'mobx';
import App from './App';

console.log(web3);

const appState = observable({
  networkId: -1,
  totalVotingMembers: 0,
  members: [],

});

ReactDOM.render(
  <App />,
  document.getElementById('app')
);
