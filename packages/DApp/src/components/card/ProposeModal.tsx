import React, { useState } from 'react'
import styled from 'styled-components'
import { getCommunityDetails } from '../../helpers/apiMock'
import { ButtonPrimary } from '../Button'
import { CardCommunity } from '../Card'
import { Input } from '../Input'
import { VotePropose } from '../votes/VotePropose'
import { Warning } from '../votes/VoteWarning'
import { ConfirmBtn } from './VoteConfirmModal'

import { useContractFunction } from '@usedapp/core'

import { useContracts } from '../../hooks/useContracts'

interface ProposeModalProps {
  availableAmount: number
  setShowConfirmModal: (val: boolean) => void
  setPublicKey: (publicKey: string) => void
  publicKey: string
}

export function ProposeModal({ availableAmount, setShowConfirmModal, setPublicKey, publicKey }: ProposeModalProps) {
  const [proposingAmount, setProposingAmount] = useState(availableAmount)
  const communityFound = getCommunityDetails(publicKey)
  const disabled = proposingAmount === 0

  const { votingContract } = useContracts()
  const { send } = useContractFunction(votingContract, 'initializeVotingRoom')

  return (
    <CommunityProposing>
      <CommunityKeyLabel>
        Community public key
        <CommunityKey
          value={publicKey}
          placeholder="E.g. 0xbede83eef5d82c4dd5d82c4dd5fa837ad"
          onChange={(e) => {
            setPublicKey(e.currentTarget.value)
          }}
        ></CommunityKey>
      </CommunityKeyLabel>

      {publicKey && communityFound && (
        <div>
          <CardCommunity community={communityFound} />
          {communityFound.validForAddition ? (
            <VoteProposeWrap>
              <VotePropose
                availableAmount={availableAmount}
                setProposingAmount={setProposingAmount}
                proposingAmount={proposingAmount}
                disabled={disabled}
              />
            </VoteProposeWrap>
          ) : (
            <WarningWrap>
              <Warning
                icon="🤏"
                text={`${communityFound.name} currently only has ${communityFound.numberOfMembers} members. A community needs more than 42 members before a vote to be added to the Status community directory can be proposed.`}
              />
            </WarningWrap>
          )}
        </div>
      )}

      {!communityFound && (
        <ProposingInfo>
          <span>ℹ️</span>
          <InfoText>To propose a community, it must have at least 42 members and have a ENS domain.</InfoText>
        </ProposingInfo>
      )}

      {communityFound && !communityFound.validForAddition ? (
        <ConfirmBtn
          onClick={() => {
            setShowConfirmModal(false)
            setPublicKey('')
          }}
        >
          OK, let’s move on! <span>🤙</span>
        </ConfirmBtn>
      ) : (
        <ProposingBtn
          disabled={!communityFound}
          onClick={() => {
            send(1, publicKey)
            setShowConfirmModal(true)
          }}
        >
          Confirm vote to add community
        </ProposingBtn>
      )}
    </CommunityProposing>
  )
}

const CommunityProposing = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
`

const CommunityKey = styled(Input)`
  width: 100%;
  margin-top: 10px;
  margin-bottom: 32px;
  font-size: 15px;
  line-height: 22px;
`
const CommunityKeyLabel = styled.label`
  width: 100%;
  font-size: 15px;
  line-height: 22px;
`

const VoteProposeWrap = styled.div`
  margin-top: 32px;
`

const ProposingInfo = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  margin-bottom: 32px;

  & > span {
    font-size: 24px;
    line-height: 32px;
    margin-right: 16px;
  }
`

const InfoText = styled.div`
  font-size: 12px;
  line-height: 16px;
  letter-spacing: 0.1px;
`

const ProposingBtn = styled(ButtonPrimary)`
  width: 100%;
  padding: 11px 0;
`
const WarningWrap = styled.div`
  margin: 24px 0;
`
