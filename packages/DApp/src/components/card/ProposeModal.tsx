import React, { useState } from 'react'
import styled from 'styled-components'
import { ButtonPrimary } from '../Button'
import { CardCommunity } from '../Card'
import { Input } from '../Input'
import { VotePropose } from '../votes/VotePropose'
import { Warning } from '../votes/VoteWarning'
import { ConfirmBtn } from './VoteConfirmModal'
import { useContractFunction } from '@usedapp/core'
import { useContracts } from '../../hooks/useContracts'
import { CommunityDetail } from '../../models/community'
import { CommunitySkeleton } from '../skeleton/CommunitySkeleton'
import { useCommunityDetails } from '../../hooks/useCommunityDetails'

interface PublicKeyInputProps {
  publicKey: string
  setPublicKey: (val: string) => void
}

function PublicKeyInput({ publicKey, setPublicKey }: PublicKeyInputProps) {
  return (
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
  )
}

interface ProposeModalProps {
  availableAmount: number
  setShowConfirmModal: (val: boolean) => void
  setCommunityFound: (community: CommunityDetail | undefined) => void
  communityFound: CommunityDetail | undefined
}

export function ProposeModal({
  availableAmount,
  setShowConfirmModal,
  setCommunityFound,
  communityFound,
}: ProposeModalProps) {
  const [proposingAmount, setProposingAmount] = useState(0)
  const [publicKey, setPublicKey] = useState('')
  const disabled = proposingAmount === 0
  const loading = useCommunityDetails(publicKey, setCommunityFound)
  const { votingContract } = useContracts()
  const { send } = useContractFunction(votingContract, 'initializeVotingRoom')

  return (
    <CommunityProposing>
      <PublicKeyInput publicKey={publicKey} setPublicKey={setPublicKey} />

      {publicKey && communityFound && (
        <ProposingData>
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
        </ProposingData>
      )}

      {!communityFound && !publicKey && (
        <ProposingInfo>
          <span>ℹ️</span>
          <InfoText>To propose a community, it must have at least 42 members and have a ENS domain.</InfoText>
        </ProposingInfo>
      )}

      {loading && publicKey && (
        <ProposingData>
          <CommunitySkeleton />
          <VoteProposeWrap>
            <VotePropose
              availableAmount={availableAmount}
              setProposingAmount={setProposingAmount}
              proposingAmount={proposingAmount}
              disabled={disabled}
            />
          </VoteProposeWrap>
        </ProposingData>
      )}

      {communityFound && !communityFound.validForAddition ? (
        <ConfirmBtn
          onClick={() => {
            setShowConfirmModal(false)
          }}
        >
          OK, let’s move on! <span>🤙</span>
        </ConfirmBtn>
      ) : (
        <ProposingBtn
          disabled={!communityFound || disabled}
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

const ProposingData = styled.div`
  width: 100%;
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
