import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import MockContract from '../build/MockContract.json'

const deploy = async () => {
    const providerName = process.env.ETHEREUM_PROVIDER
    const privateKey = process.env.ETHEREUM_PRIVATE_KEY
    if (privateKey && providerName) {
        console.log(`deploying on ${providerName}`)
        const provider = ethers.getDefaultProvider(process.env.ETHEREUM_PROVIDER)
        const wallet = new ethers.Wallet(privateKey, provider)

        const mockContract = await deployContract(wallet, MockContract)
        console.log(`Contract deployed with address: ${mockContract.address}`)
    }
}

deploy()

