//SPDX-License-Identifier:UNLICENSED
pragma solidity >=0.5.0 <0.9.0;

contract ERC721{

    //STATE VARIABLES
    uint256 public _currentIndex;
    uint256 private _maxBatchSize;
    uint256 public _startIndex;

    //STRUCTS
    struct RelayerPermission{
        address relayer;
        uint256 deadline;
    }

    //MAPPINGS (STATE)
    mapping (address => uint256) internal _balances; //Kepps track of balances of all owner addresses
    mapping (uint256 => address) public _owners; //Keeps track of all tokens' owners
    mapping (address=> mapping(address => bool)) private _operatorAprrovals; //Keeps track of operator approval list for each owner
    mapping (uint256 => address) private _tokenApprovals; //Keeps track of all the approvals given for tokenIds
    mapping (uint256 => RelayerPermission) public permissions; //Keeps track of all the permissions given through permit()

    //EVENTS
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved); //Emitted when operator approval is enabled/disabled
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId); //Emitted when a third party is approved for NFT corresponding to tokenId
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId); //Emitted when a NFT transfer takes place
    event Permission(address indexed _signer, address indexed _spender, uint256 _tokenId, uint256 deadline); //Emitted when permit function is used in collection

    /*
    ** Initializes 2 values on deployment of contract
    ** Set currentIndex to start index set by deployer
    ** Set max batch size for batch minting
    */
    constructor(uint256 startIndex_ , uint256 maxBatchSize_){
        _startIndex = startIndex_;
        _currentIndex = startIndex_;
        _maxBatchSize = maxBatchSize_;
    }
    
    /*
    ** Returns the number of tokens owned by 'owner'
    ** Parameters: 1 :-
       1) 'owner' --> TYPE: 'address'  USE: Address of owner 
    ** Checks --> Owner should not be zero address
    */
    function balanceOf(address owner) public view returns(uint256){
        require(owner != address(0), "Owner address cannot be zero");
        return _balances[owner];
    }

    /*
    ** Returns owner of the NFT identified by 'tokenId'
    ** Following Azuki's ERC721 logic, look for address from tokenId to smallest possible tokenId
    ** This may significantly increase gas fees if maxBatchSize is too big.
    ** Parameters: 1 :-
       1) 'tokenId' --> TYPE: 'uint256'  USE: Identifier of NFT
    */
    function ownerOf(uint256 tokenId) public view returns(address){
        uint256 current = tokenId;
        if(_startIndex <= current && current < _currentIndex){
        do{
            address owner = _owners[current];
            if(owner != address(0)){
                return owner;
            }
            current--;
        }while(current>=0);
        }
        return address(0);
    }

    /********************OPERATOR FUNCTIONS************************/

    /*
    ** Enables/Disables a operator to manage all of msg.sender's tokens
    ** Parameters: 2 :-
       1) 'operator' --> TYPE: 'address'  USE: Address of operator
       2) 'approved' --> TYPE: 'boolean'  USE: For enabling/disabling 
    ** Emits ApprovalForAll event
    */
    function setApprovalForAll(address operator, bool approved) public {
        _operatorAprrovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /*
    ** Checks whether an address is an operator for another address
    ** Parameters: 2 :-
       1) 'owner' --> TYPE: 'address'  USE: Address of owner
       2) 'operator' --> TYPE: 'address'  USE: Address of operator
    */
    function isApprovedForAll(address owner, address operator) public view returns(bool) {
        return _operatorAprrovals[owner][operator];
    }

    /********************APPROVAL FUNCTIONS************************/

    /*
    ** Updates an unapproved address for an NFT
    ** Parameters: 2 :-
       1) 'to' --> TYPE: 'address'  USE: Address of third party
       2) 'tokenId' --> TYPE: 'uint256'  USE: Identifier of NFT
    ** Checks --> If msg.sender is owner or operator
    ** Emits Approval event
    */
    function approve(address to, uint256 tokenId) public{
        address owner = ownerOf(tokenId);
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "msg.sender is not owner or operator");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /*
    ** Get approved address for tokenId
    ** Parameters: 1 :-
       1) 'tokenId' --> TYPE: 'uint256'  USE: Identifier of NFT
    ** Checks --> Token ID should exist => If NFT is assigned to zero address throw error
    */
    function getApproved(uint256 tokenId) public view returns(address){
        require(ownerOf(tokenId) != address(0), "Token ID does not exist");
        return _tokenApprovals[tokenId];
    }

    /********************TRANSFER FUNCTIONS************************/

    /*
    ** Transfers NFT token between addresses
    ** Parameters: 3 :-
       1) 'from' --> TYPE: 'address'  USE: Address of owner
       2) 'to' --> TYPE: 'address'  USE: Address of receiver
       3) 'tokenId' --> TYPE: 'uint256' USE: Token ID of NFT to be transferred
    ** Checks --> msg.sender should be owner, operator, approved address or permitted relayer address
              --> 'from' should be current owner
              --> 'to' should not be zero address
              --> Token ID should exist => If NFT is assigned to zero address throw error 
    ** Emits Transfer event
    */
    function transferFrom(address from, address to, uint256 tokenId) public virtual{
        address owner = ownerOf(tokenId);
        require(
            msg.sender == owner ||
            msg.sender == getApproved(tokenId)||
            isApprovedForAll(owner, msg.sender)||
            permissions[tokenId].relayer == msg.sender && permissions[tokenId].deadline > block.timestamp, 
            "msg.sender is not owner or approved address"
        );
        require(from == owner, "From address should be owner");
        require(to != address(0), "To address should not be zero address");
        require(ownerOf(tokenId) != address(0), "Token ID does not exist");

        //Clear approval
        _tokenApprovals[tokenId] = address(0);

        //Update balances
        _balances[from] -= 1;
        _balances[to] += 1;

        //Change ownership
        _owners[tokenId] = to;

        //Check if tokenId was in middle of tokens minted as a batch by from address. 
        //If yes to no cause the ownerOf() to revert, update next tokenId's owner to from address.
        uint256 nextTokenId = tokenId + 1;
        if(_owners[nextTokenId] == address(0) && _currentIndex > nextTokenId){ //Check if next address is zero and is not overflowing
            _owners[nextTokenId] = from;
        }

        emit Transfer(from, to, tokenId);
    }

    /*
    ** It is similar to standard transferFrom but also checks if receiving address is a smart contract or not and if it uses the IERC721Received interface
    ** Parameters : 4 :-
       1) 'from' --> TYPE: 'address'  USE: Address of owner
       2) 'to' --> TYPE: 'address'  USE: Address of receiver
       3) 'tokenId' --> TYPE: 'uint256' USE: Token ID of NFT to be transferred
       4) 'data' --> TYPE: 'bytes' USE: To send additional instructions to receiver smart contract
    ** Checks --> If receiver smart contract is capable of receiving NFTs || If receiver smart contract has IERC721Received interface implemented
    */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public{
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(), "ERC721Received interface not implemented by receiver");
    }

    /*
    ** safeTransferFrom with no 'data' parameter. No additional instructions sent to receiver contract
    ** Parameters : 3 :-
       1) 'from' --> TYPE: 'address'  USE: Address of owner
       2) 'to' --> TYPE: 'address'  USE: Address of receiver
       3) 'tokenId' --> TYPE: 'uint256' USE: Token ID of NFT to be transferred
    */
    function safeTransferFrom(address from, address to, uint256 tokenId) public{
        safeTransferFrom(from, to, tokenId, "");
    }

    /*
    ** Creates multiple tokens and sends to msg.sender
    ** Parameters : 2 :-
       1) 'to' --> TYPE: 'address'  USE: Address of minter
       2) 'quantity' --> TYPE: 'uint256' USE: Number of NFTs to be minted
    ** Checks --> Quantity should be more than 0 and less than max batch size.
    */
    function _mint(address to, uint256 quantity) public{
        uint256 startTokenId = _currentIndex;
        require(quantity > 0 && quantity <= _maxBatchSize, "Quantity is invalid. Either too large or too small");
        _balances[to] += quantity; //Update balance of to address
        _owners[startTokenId] = to; //Set owner for token
        uint256 updatedIndex = startTokenId;
        uint256 end = updatedIndex + quantity;

        do {
            emit Transfer(address(0), to, updatedIndex++); //Mint is recognised by Block explorer as well as OpenSea as a transfer from zero address to msg.sender
        } while (updatedIndex < end);

        _currentIndex = updatedIndex;
    }

    /*
    ** This is used to transfer control to receiver smart contract and may be vulnerable to re-entrancy attacks. Thus it is recommended to make use of re-entrancy guards.
    ** Here we are assuming that the receiver can only be an externally owned account. Thus we simply return true.
    ** In general this function uses the IERC721Received interface to call receiver contract and check if the interface is implemented.
    */
    function _checkOnERC721Received() private pure returns(bool){
            return true;
    }

    /*
    ** Part of EIP165.
    ** Allows us to query for a certain interface implementation. Allows us to check for functionality.
    ** Parameters : 1 :-
       1) 'interfaceId' --> TYPE: 'bytes4' USE: Interface ID which is being queried
    */
    function supportsInterface(bytes4 interfaceId) public pure virtual returns(bool){
        return interfaceId == 0x80ac58cd;  //Hardcoded value from documentation in EIP
    }
    
}