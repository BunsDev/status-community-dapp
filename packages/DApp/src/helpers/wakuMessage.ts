import { JsonRpcSigner } from '@ethersproject/providers'
import { BigNumber } from 'ethers'
import { packAndArrayify } from './ethMessage'
import { Waku, WakuMessage } from 'js-waku'
import { recoverAddress } from './ethMessage'
import { utils } from 'ethers'
import proto from './loadProtons'
import { WakuFeatureData, WakuVoteData } from '../models/waku'
import { TypedVote } from '../models/TypedData'

function getContractParameters(
  address: string,
  room: number,
  type: number,
  sntAmount: number
): [string, BigNumber, BigNumber] {
  return [address, BigNumber.from(room).mul(2).add(type), BigNumber.from(sntAmount)]
}

export function filterVerifiedMessages(
  messages: WakuVoteData[] | undefined,
  alreadyVoted: string[],
  getTypedData: (data: [string, BigNumber, BigNumber]) => TypedVote
) {
  if (!messages) {
    return []
  }
  const verified: [string, BigNumber, BigNumber, string, string][] = []

  messages.forEach((msg) => {
    const params = getContractParameters(
      msg.address,
      msg.sessionID,
      msg.vote == 'yes' ? 1 : 0,
      msg.sntAmount.toNumber()
    )

    if (utils.getAddress(recoverAddress(getTypedData(params), msg.sign)) == msg.address) {
      const addressInVerified = verified.find((el) => el[0] === msg.address)
      const addressInVoted = alreadyVoted.find((el: string) => el === msg.address)
      const splitSig = utils.splitSignature(msg.sign)
      if (!addressInVerified && !addressInVoted) {
        verified.push([...params, splitSig.r, splitSig._vs])
      }
    }
  })
  return verified
}

function decodeWakuVote(msg: WakuMessage): WakuVoteData | undefined {
  try {
    if (!msg.payload) {
      return undefined
    }
    const data = proto.WakuVote.decode(msg.payload)
    if (data && data.address && data.nonce && data.sessionID && data.sign && data.sntAmount && data.vote) {
      return { ...data, sntAmount: BigNumber.from(data.sntAmount) }
    } else {
      return undefined
    }
  } catch {
    return undefined
  }
}

export function decodeWakuVotes(messages: WakuMessage[] | null) {
  return messages?.map(decodeWakuVote).filter((e): e is WakuVoteData => !!e)
}

export async function receiveWakuMessages(waku: Waku, topic: string, room: number) {
  const contentTopics = [topic + room.toString()]
  const messages = await waku.store.queryHistory({ contentTopics })
  return decodeWakuVotes(messages)
}

function decodeWakuFeature(msg: WakuMessage): WakuFeatureData | undefined {
  try {
    if (!msg.payload) {
      return undefined
    }
    const data = proto.WakuFeature.decode(msg.payload)
    if (data && data.publicKey && data.sign && data.sntAmount && data.timestamp && data.voter) {
      return {
        ...data,
        msgTimestamp: msg.timestamp ?? new Date(0),
        timestamp: new Date(data.timestamp),
        sntAmount: BigNumber.from(data.sntAmount),
      }
    } else {
      return undefined
    }
  } catch {
    return undefined
  }
}

export function decodeWakuFeatures(messages: WakuMessage[] | null) {
  return messages?.map(decodeWakuFeature).filter(verifyWakuFeatureMsg)
}

export async function receiveWakuFeatureMsg(waku: Waku | undefined, topic: string) {
  if (waku) {
    const messages = await waku.store.queryHistory({ contentTopics: [topic] })
    return decodeWakuFeatures(messages)
  }
}

function verifyWakuFeatureMsg(data: WakuFeatureData | undefined): data is WakuFeatureData {
  if (!data) {
    return false
  }
  const types = ['address', 'uint256', 'address', 'uint256']
  const message = [data.voter, data.sntAmount, data.publicKey, data.timestamp.getTime()]
  const verifiedAddress = utils.verifyMessage(packAndArrayify(types, message), data.sign)

  if (data.msgTimestamp?.getTime() != data.timestamp.getTime() || verifiedAddress != data.voter) {
    return false
  }
  return true
}

export async function createWakuFeatureMsg(
  account: string | null | undefined,
  signer: JsonRpcSigner | undefined,
  sntAmount: BigNumber,
  publicKey: string,
  contentTopic: string
) {
  if (!account || !signer) {
    return undefined
  }

  const signerAddress = await signer?.getAddress()
  if (signerAddress != account) {
    return undefined
  }
  const timestamp = new Date()

  const types = ['address', 'uint256', 'address', 'uint256']
  const message = [account, sntAmount, publicKey, BigNumber.from(timestamp.getTime())]
  const sign = await signer.signMessage(packAndArrayify(types, message))

  if (sign) {
    const payload = proto.WakuFeature.encode({
      voter: account,
      sntAmount: utils.arrayify(sntAmount),
      publicKey,
      timestamp,
      sign,
    })

    const msg = WakuMessage.fromBytes(payload, {
      contentTopic,
      timestamp,
    })
    return msg
  }
  return undefined
}

export async function createWakuMessage(
  account: string | null | undefined,
  signer: JsonRpcSigner | undefined,
  room: number,
  voteAmount: number,
  type: number,
  topic: string,
  getTypedData: (data: [string, BigNumber, BigNumber]) => any,
  sig?: string
) {
  if (!account || !signer) {
    return undefined
  }
  const provider = signer.provider

  const signerAddress = await signer?.getAddress()
  if (signerAddress != account) {
    return undefined
  }

  const message = getContractParameters(account, room, type, voteAmount)
  const data = getTypedData(message)

  const signature = sig ? sig : await provider?.send('eth_signTypedData_v3', [account, JSON.stringify(data)])
  if (signature) {
    const payload = proto.WakuVote.encode({
      address: account,
      vote: type == 1 ? 'yes' : 'no',
      sntAmount: utils.arrayify(BigNumber.from(voteAmount)),
      sign: signature,
      nonce: 1,
      sessionID: room,
    })

    const msg = WakuMessage.fromBytes(payload, { contentTopic: topic + room.toString() })
    return msg
  }
  return undefined
}

export default { create: createWakuMessage, receive: receiveWakuMessages, filterVerified: filterVerifiedMessages }
