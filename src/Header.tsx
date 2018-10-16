import React from 'react';
import styled from 'styled-components';

const HeaderBackground = styled.div`
  width: 100%;
  background-color: #00F;
`;

export default class Header extends React.Component {
  render() {
    return (
      <HeaderBackground>
        <div>Common Theory</div>
      </HeaderBackground>
    );
  }
}
