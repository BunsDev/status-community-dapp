import React from 'react'
import styled from 'styled-components'
import { Colors } from '../../constants/styles'
import { addCommas } from '../../helpers/addCommas'
import { VoteType, voteTypes } from './../../constants/voteTypes'
import { CurrentVoting } from '../../models/community'
import { VoteGraphBar } from './VoteGraphBar'

import { formatTimeLeft } from '../../helpers/fomatTimeLeft'

export interface VoteChartProps {
  vote: CurrentVoting
  voteWinner?: number
  proposingAmount?: number
  selectedVote?: VoteType
}

export function VoteChart({ vote, voteWinner, proposingAmount, selectedVote }: VoteChartProps) {
  const voteConstants = voteTypes[vote.type]
  return (
    <Votes>
      <VotesChart>
        <VoteBox style={{ filter: voteWinner && voteWinner === 2 ? 'grayscale(1)' : 'none' }}>
          <p style={{ fontSize: voteWinner === 1 ? '42px' : '24px', marginTop: voteWinner === 2 ? '18px' : '0' }}>
            {voteConstants.against.icon}
          </p>
          <span>
            {' '}
            {addCommas(vote.voteAgainst.toNumber())} <span style={{ fontWeight: 'normal' }}>SNT</span>
          </span>
        </VoteBox>
        <TimeLeft>{formatTimeLeft(vote.timeLeft)}</TimeLeft>
        <VoteBox style={{ filter: voteWinner && voteWinner === 1 ? 'grayscale(1)' : 'none' }}>
          <p style={{ fontSize: voteWinner === 2 ? '42px' : '24px', marginTop: voteWinner === 1 ? '18px' : '0' }}>
            {voteConstants.for.icon}
          </p>
          <span>
            {' '}
            {addCommas(vote.voteFor.toNumber())} <span style={{ fontWeight: 'normal' }}>SNT</span>
          </span>
        </VoteBox>
      </VotesChart>

      <VoteGraphBar
        votesFor={vote.voteFor.toNumber()}
        votesAgainst={vote.voteAgainst.toNumber()}
        voteWinner={voteWinner}
        proposingAmount={proposingAmount}
        selectedVote={selectedVote}
      />
    </Votes>
  )
}

const Votes = styled.div`
  display: flex;
  flex-direction: column;
  margin-bottom: 32px;
  width: 100%;
`
const VotesChart = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 13px;
`

const VoteBox = styled.div`
  display: flex;
  flex-direction: column;
  align-content: center;
  font-size: 12px;
  text-align: center;
  font-weight: normal;

  & > p {
    font-size: 24px;
    line-height: 100%;
  }

  & > span {
    font-weight: bold;
    margin-top: 8px;
  }
`

const TimeLeft = styled.p`
  font-size: 12px;
  line-height: 16px;
  letter-spacing: 0.1px;
  color: ${Colors.GreyText};
`
