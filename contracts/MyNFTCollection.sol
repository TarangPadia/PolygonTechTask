//SPDX-License-Identifier:UNLICENSED
pragma solidity >=0.5.0 <0.9.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyNFTCollection is ERC721{

    //STATE VARIABLES
    string public name; //ERC721Metadata
    string public symbol; //ERC721Metadata
    string  public constant version  = "1";
    string private baseURI;
    uint256 private _tokenCount;

    //EIP712 components
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;


    //MAPPINGS
    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => uint) public nonces;

    /*
    ** Initializes 6 values on deployment of contract
    ** Set name, symbol, initial token count and baseURI for metadata following ERC721Metadata Interface
    ** Create Domain Separator hash (EIP712) for implementing permit functionality
    */
    constructor(string memory _name, string memory _symbol, string memory _baseURI, uint256 startIndex_ , uint256 maxBatchSize_ , uint256 chainId_) ERC721(startIndex_, maxBatchSize_){
        name = _name;
        symbol = _symbol;
        _tokenCount = startIndex_;
        baseURI = _baseURI;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_name)),
                keccak256(bytes(version)),
                chainId_,
                address(this)
            )
        );
    }

    /*
    ** Returns tokenURI for a token ID.
    ** Used by frontend of applications to visualize NFTs by retrieving metadata from the returned URL
    ** Parameters: 1 :-
       1) 'tokenId' --> TYPE: 'uint256'  USE: Identifier of NFT 
    ** Checks --> Token ID should exist => If NFT is assigned to zero address throw error
    */
    function tokenURI(uint256 tokenId) public view returns(string memory){   //ERC721Metadata
        require(ownerOf(tokenId) != address(0), "Token ID does not exist");
        return _tokenURIs[tokenId];
    }

    /*
    ** Creates new NFT in our collection "MyNFTcollection"
    ** Parameters: 1 :-
       1) 'quantity' --> TYPE: 'uint256' USE: Number of tokens to be minted
    */
    function mint(uint256 quantity) public {
        uint256 updatedIndex = _tokenCount; //Will act as token identifier
        uint256 end = updatedIndex + quantity;
        do {
            _tokenURIs[updatedIndex] = string(abi.encodePacked(baseURI, Strings.toString(updatedIndex))); //Set token URI for token batch
            updatedIndex++;
        } while (updatedIndex < end);
        _mint(msg.sender, quantity);
    }

    //Override transferFrom from ERC721 contract, nonce for each permission is incremented during transfer rather than during permission (Different from ERC20 permit via EIP2612 standard)
    function transferFrom(address from, address to, uint256 tokenId) public override{
        nonces[tokenId]++;
        super.transferFrom(from, to, tokenId);
    }

    /*
    ** Allows the use of meta transactions through a relayer service like Biconomy etc.
    ** v,r,s parameters are from the signature of the owner of tokenId obtained on the frontend
    ** Performs ecrecover validation to get the public address and if ecrecover() returns zero address, the signature is invalid
    ** Emits the Permission event and set a permission with a deadline. Later used in transferFrom function. 
    ** Allows to perform gasless transactions and also protection from unlimited tokenId approval. Approval is time-limited.  
    */
    function permit(address spender, uint256 tokenId, uint256 nonce, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
    {
        bytes32 digest =
            keccak256(abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH,
                                     spender,
                                     nonce,
                                     tokenId))
        ));

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "Invalid signature");
        require(deadline == 0 || block.timestamp <= deadline, "Deadline expired");
        require(nonce == nonces[tokenId]+1, "Invalid nonce");
        permissions[tokenId].relayer = spender;
        permissions[tokenId].deadline = deadline;
        emit Permission(signer, spender, tokenId, deadline);
    }

    /*
    ** Overrides function in ERC721 contract.
    ** Adds a second interface id for added functionality i.e., name, symbol,tokenURI (ERC721Metadata)
    ** Parameters: 1 :-
        3) 'interfaceId' --> TYPE: 'bytes4' USE: Interface ID which is being queried
    */
    function supportsInterface(bytes4 interfaceId) public pure override returns(bool){
        return interfaceId == 0x80ac58cd || interfaceId == 0x5b5c139f; //Hardcoded values from documentation in EIP
    }
    
    
}