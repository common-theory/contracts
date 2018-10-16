import React from 'react';
import styled from 'styled-components';
import { observer } from "mobx-react"

const HeaderBackground = styled.div`
  width: 100%;
  padding: 8px;
  background-color: #00F;
`;

const LogoText = styled.span`
  color: white;
  font-family: Helvetica;
`;

@observer
export default class Header extends React.Component {
  render() {
    return (
      <HeaderBackground>
        <LogoText>Common Theory</LogoText>
      </HeaderBackground>
    );
  }
}
