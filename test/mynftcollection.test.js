const {expect} = require('chai');
const { MockProvider,deployContract } = require('ethereum-waffle');
const { ecsign } = require('ethereumjs-util');
const { hexlify } = require('ethers/lib/utils');
const { ethers } = require('hardhat');
const myNFTCollection = require('../artifacts/contracts/MyNFTCollection.sol/MyNFTCollection.json');

function getApprovalDigest(spender, tokenId, nonce, deadline, DOMAIN_SEPARATOR, PERMIT_TYPEHASH) {
    return ethers.utils.keccak256( 
      ethers.utils.solidityPack(
        ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
        [
          '0x19',
          '0x01',
          DOMAIN_SEPARATOR,
          ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
              ['bytes32', 'address', 'uint256', 'uint256', 'uint256'],
              [PERMIT_TYPEHASH, spender, tokenId, nonce, deadline]
            )
          )
        ]
      )
    )
  }
  

describe("MyNFTCollection", function(){
    let MyNFTCollection;
    let deployedNFTCollection
    let addr1;
    let addr2;
    let addr3;
    let addrs;

    beforeEach(async function(){
        MyNFTCollection = await ethers.getContractFactory("MyNFTCollection");
        [addr1, addr2, addr3, ...addrs] = await ethers.getSigners()
        deployedNFTCollection = await MyNFTCollection.deploy("Heros", "HERO", "https://ipfs.io/ipfs/QmdKektfKmAEw7f692D7G5yQbacQomeaRmgMDnpqG9bcJv/", 1, 5, 42)
    })

    describe("Deployment", function(){
        it("Should have a name, symbol and version", async function(){
            const name = await deployedNFTCollection.name()
            const symbol = await deployedNFTCollection.symbol()
            const version = await deployedNFTCollection.version()

            expect(name).to.equal("Heros")
            expect(symbol).to.equal("HERO")
            expect(version).to.equal("1")
        })
        it("Supports interfaces for ERC721 and ERC721Metadata functionality", async function(){
            expect(await deployedNFTCollection.supportsInterface(0x80ac58cd)).to.equal(true)
            expect(await deployedNFTCollection.supportsInterface(0x5b5c139f)).to.equal(true)
        })
    })

    describe("Minting Functionality", function(){
        it("Should mint a batch of 5", async function(){
            await deployedNFTCollection.mint(5)
            const balance = await deployedNFTCollection.balanceOf(addr1.address)
            expect(balance).to.equal(5)
        })
        it("Should revert batch size higher than 5 or equal to 0", async function(){
            await expect(deployedNFTCollection.mint(6)).to.be.revertedWith('Quantity is invalid. Either too large or too small')
            await expect(deployedNFTCollection.mint(0)).to.be.revertedWith('Quantity is invalid. Either too large or too small')
        })
        it("Should return proper owner for batch minting", async function(){
            await deployedNFTCollection.mint(5)
            expect(await deployedNFTCollection.ownerOf(1)).to.equal(addr1.address)
            expect(await deployedNFTCollection.ownerOf(2)).to.equal(addr1.address)
            expect(await deployedNFTCollection.ownerOf(3)).to.equal(addr1.address)
            expect(await deployedNFTCollection.ownerOf(4)).to.equal(addr1.address)
            expect(await deployedNFTCollection.ownerOf(5)).to.equal(addr1.address)
        })
        it("Should not be owner of higher than batch minted", async function(){
            await deployedNFTCollection.mint(5)
            expect(await deployedNFTCollection.ownerOf(6)).to.equal('0x0000000000000000000000000000000000000000')
        })
        it("Should return appropriate tokenURI", async function(){
            await deployedNFTCollection.mint(1)
            expect(await deployedNFTCollection.tokenURI(1)).to.equal('https://ipfs.io/ipfs/QmdKektfKmAEw7f692D7G5yQbacQomeaRmgMDnpqG9bcJv/1')
        })
    })

    describe("Operator approval", function(){
        it("Should set approval for operator", async function(){
            await deployedNFTCollection.mint(1)
            await deployedNFTCollection.setApprovalForAll(addr2.address, true)
            expect(await deployedNFTCollection.isApprovedForAll(addr1.address, addr2.address)).to.equal(true)
        })
        it("Allow transfer for operator", async function(){
            await deployedNFTCollection.mint(1)
            await deployedNFTCollection.setApprovalForAll(addr2.address, true)
            await deployedNFTCollection.connect(addr2).transferFrom(addr1.address, addr3.address, 1)
            expect(await deployedNFTCollection.ownerOf(1)).to.equal(addr3.address)
            expect(await deployedNFTCollection.balanceOf(addr1.address)).to.equal(0)
            expect(await deployedNFTCollection.balanceOf(addr3.address)).to.equal(1)
        })
    })

    describe("Normal approval", function(){
        it("Should set approval for third party address", async function(){
            await deployedNFTCollection.mint(1)
            await deployedNFTCollection.approve(addr2.address, 1)
            expect(await deployedNFTCollection.getApproved(1)).to.equal(addr2.address)
        })
        it("Allow transfer for approved third party", async function(){
            await deployedNFTCollection.mint(1)
            await deployedNFTCollection.approve(addr2.address, 1)
            await deployedNFTCollection.connect(addr2).transferFrom(addr1.address, addr3.address, 1)
            expect(await deployedNFTCollection.ownerOf(1)).to.equal(addr3.address)
            expect(await deployedNFTCollection.balanceOf(addr1.address)).to.equal(0)
            expect(await deployedNFTCollection.balanceOf(addr3.address)).to.equal(1)
        })
    })

})

describe("Permit functionality", function(){
    
    let deployedContractForPermit
    const provider = new MockProvider()
    const [wallet, wallet2, wallet3, other] = provider.getWallets()
    beforeEach(async function(){
        deployedContractForPermit = await deployContract(wallet, myNFTCollection, ["Heros", "HERO", "https://ipfs.io/ipfs/QmdKektfKmAEw7f692D7G5yQbacQomeaRmgMDnpqG9bcJv/", 1, 5, 42])
    })
    
    it("Perform meta transaction", async function(){
        await deployedContractForPermit.mint(1)
        const DOMAIN_SEPARATOR = await deployedContractForPermit.DOMAIN_SEPARATOR()
        const PERMIT_TYPEHASH = await deployedContractForPermit.PERMIT_TYPEHASH()
        const deadline = ethers.constants.MaxUint256
        const nonce = await deployedContractForPermit.nonces(wallet.address)
        const digest = getApprovalDigest(
            wallet2.address,
            1,
            nonce,
            deadline,
            DOMAIN_SEPARATOR,
            PERMIT_TYPEHASH
        )
        const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

        await expect(deployedContractForPermit.connect(wallet2).permit(wallet2.address, 1, nonce, deadline, v, hexlify(r), hexlify(s),{gasLimit: 3000000 }))
        .to.emit(deployedContractForPermit, 'Permission')
        .withArgs(wallet.address, wallet2.address, 1, deadline)

        const relayerPermission = await deployedContractForPermit.permissions(1)
        expect(relayerPermission.relayer).to.equal(wallet2.address)
        expect(relayerPermission.deadline).to.equal(deadline)
        
        await deployedContractForPermit.connect(wallet2).transferFrom(wallet.address, wallet3.address, 1,{gasLimit: 3000000 })
        expect(await deployedContractForPermit.ownerOf(1)).to.equal(wallet3.address)
        expect(await deployedContractForPermit.balanceOf(wallet.address)).to.equal(0)
        expect(await deployedContractForPermit.balanceOf(wallet3.address)).to.equal(1)
            
    })
})