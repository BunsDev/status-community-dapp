import styled from 'styled-components'
import { Colors } from '../constants/styles'

export const Button = styled.button`
  color: ${Colors.White};
  border-radius: 8px;
`

export const ButtonPrimary = styled(Button)`
  background: ${Colors.Violet};
  font-weight: bold;
  font-size: 15px;
  line-height: 24px;

  &:not(:disabled):hover {
    background: ${Colors.VioletDark};
  }

  &:not(:disabled):active,
  &:not(:disabled):focus {
    background: ${Colors.VioletLight};
  }

  &:disabled {
    background: ${Colors.GrayDisabledLight};
    color: ${Colors.GreyTextDisabled};
    filter: grayscale(1);
  }
`
export const ButtonSecondary = styled(Button)`
  background: ${Colors.VioletSecondary};
  color: ${Colors.VioletDark};
  line-height: 24px;

  &:not(:disabled):hover {
    background: ${Colors.VioletSecondaryDark};
  }

  &:not(:disabled):active {
    background: ${Colors.VioletSecondaryLight};
  }

  &:disabled {
    background: ${Colors.GrayDisabledLight};
    filter: grayscale(1);
  }
`

export const VoteSendingBtn = styled.button`
  font-weight: 500;
  font-size: 15px;
  line-height: 22px;
  margin-top: 24px;
  margin-bottom: -16px;
  color: ${Colors.VioletDark};

  &:hover {
    color: ${Colors.Violet};
  }

  &:active {
    color: ${Colors.VioletDark};
  }
`

export const VotesBtns = styled.div`
  display: flex;
  justify-content: space-between;
  width: 100%;
`
export const VoteBtn = styled(ButtonSecondary)`
  width: 187px;
  padding: 11px 46px;
  font-weight: 500;
  font-size: 15px;
  line-height: 22px;

  & > span {
    font-size: 20px;
  }

  @media (max-width: 768px) {
    width: 305px;
  }
`
