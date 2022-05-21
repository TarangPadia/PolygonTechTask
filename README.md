# Polygon Technical Task
Polygon Technical Task - Homemade ERC721 compliant smart contract with optimization for gas in mint and transferFrom (Using Azuki's approach + Standard gas reduction techniques) with permit functionality compliant with EIP4494.

# Gas Optimization
The optimization for gas is done for batch minting using Azuki's method. 
<br/>
<b>Reference:</b> ERC721A compliance <a href="https://www.erc721a.org/" target="_blank">Click here for reference</a>
<br/>
PS: The ERC721A contract is only used as a reference, with a few tweaks made inorder to implement other functionalities.
<br />

<b>Explanation</b>
<br/>
Azuki's contract enables minting of multiple NFTs (ERC721 compliant), essentially for the gas fees close to minting a single NFT. 
<br/>
There are mainly 2 optimizations:
<br/>
<ul>
  <li>
    <b>Optimization 1:</b> Removing duplicate storage from OpenZepplin's ERC721Enumerable. Here the assumption is that tokens are stored in a sequential manner, i.e., 1,2,3,4,5......upto total number of NFTs minted.
  </li>
  <li>
    <b>Optimization 2:</b> Updating the owner's balance once per batch mint request, instead of per minted NFT. The owner balance is incremented by the number of NFTs minted i one transaction. The tokenId --> address mapping is set only for the lowest tokenId in the batch mint and all other tokens are assigned a value of address(0). The ownerOf() function contains more complex implementation i.e., finding the owner of tokenId through the use of loops. Thus the main objective is that, since user does not pay gas fees for reads, more complex implementation is shifted to reads than writes, this saves up a significant amount of gas fees specially if tokens are minted in a moderate quantity like 12-15.
  </li>
 </ul>
 <br/>
 The only downside to this method is that the batch size should be maintained between a smaller range of values. The main reason being that once the batch size crosses the bigger numbers, the transfer fees increases tremendously due to the use of ownerOf() method in the require condition. 
<br />
See issue here for reference: <a href="https://github.com/chiru-labs/ERC721A/issues/145" target="_blank">High gas on transferFrom issue</a>
<br />
The testing for the Azuki method is done in the test file with describe block "MyNFTCollection". Tests for this functionality were performed using ether.js library along with chai written in Mocha framework.
<br/>
<br/>
<b>Other Gas optimization techniques: </b>
<ul>
  <li>
    The other optimization techniques used include short circuiting in transferFrom() in the require conditions, mainly to allow faster and less complex comparisons to be made earlier in a series of comparisons, such that once any smaller condition is true, the condition is satified and heavier complex comparisons are not implemented.
  </li>
  <li>
    In loops, the state variables are assigned to local variables then the local variables are used in loops. Once final value is calculated the state variable directly takes the final value. This stops continuous modification to state variables which is costly.
  </li>
 </ul>
 

# Permit Functionality
The permit function is used for gasless approvals for NFTs compliant with EIP4494. This is very similar to the EIP2612 used for gasless meta transactions for ERC20 compliant tokens. 
<br/> <b>Reference: </b> <a href="https://eips.ethereum.org/EIPS/eip-4494" target="_blank">Click here for reference</a>
<br/>
<br/>
The permit() is basically called by the relayer who makes the approval for a particular tokenId on behalf of the owner of the token. This is done by carryforwarding the v,r and s components for a signed piece of data to the permit(). The data which is signed by the owner is replicated in the smart contract. This is through the DOMAIN_SEPARATOR which makes the signature verification invalid incase of environment (chain ID, name, version, address of verifying contract) mistmatch. The other is the PERMIT_TYPEHASH which makes sure the signature is for the permit() implementation by the relayer. All of these hashes are combined to a bigger hash along with verifications for relayer/spender, tokenId ,nonce and deadline. The nonce gives the signature aunique value which does not allow the same relayer to get permission for the same tokenID for the same environment and for the same deadline. Thus, protects the user from repeated approval request without their knowledge. 
<br/>
<br/>
The relayer used in the test is another wallet, created using ethereum waffle testing framework. This allows for signing by owner and relaying the transaction by another wallet. Thus, the owner who is approving is safe from repeated approvals and also makes approvals gasless as gas is paid by the relayer. The fees can be collected from the owner in any other crypto currency than the native currency, offering much more flexibility.


# Testing

All tests are performed in the hardhat environment, which is also used for compilation of smart contracts. Other libraries used include ethers.js, ethereum waffle and chai and Mocha framework.
