import { useCallback } from 'react'
import { useWaku } from '../providers/waku/provider'
import { useEthers, useSigner } from '@usedapp/core'
import { config } from '../config'
import { createWakuVote } from '../helpers/wakuVote'
import { useTypedVote } from './useTypedVote'
import { EncoderV0 } from 'js-waku/lib/waku_message/version_0'

export function useSendWakuVote() {
  const { waku } = useWaku()
  const signer = useSigner()
  const { account } = useEthers()
  const { getTypedVote } = useTypedVote()

  const sendWakuVote = useCallback(
    async (voteAmount: number, room: number, type: number) => {
      const timestamp = Math.floor(Date.now() / 1000)
      const msg = await createWakuVote(account, signer, room, voteAmount, type, timestamp, getTypedVote)
      if (msg) {
        if (waku) {
          await waku.lightPush.push(new EncoderV0(config.wakuConfig.wakuTopic + room.toString()), { payload: msg })
        } else {
          alert('error sending vote please try again')
        }
      }
    },
    [waku, signer, account, getTypedVote]
  )

  return sendWakuVote
}
