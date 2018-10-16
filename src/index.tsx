import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import AppStore from './AppStore';
import { Provider } from 'mobx-react';

const stores = {
  appStore: new AppStore()
};

ReactDOM.render(
  <Provider { ...stores }>
    <App />
  </Provider>,
  document.getElementById('app')
);
