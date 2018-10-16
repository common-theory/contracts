import React from 'react';
import Header from './Header';
import { observer } from 'mobx-react';

@observer
export default class App extends React.Component {
  render() {
    return (
      <div>
        <Header />
        <div>text</div>
      </div>
    );
  }
}
