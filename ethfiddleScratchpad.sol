
//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.18;


contract ERC20 {
  mapping (address=>uint) balances;
  mapping (address => mapping(address=>uint)) approvals;

  function getBalance(address holder) public view returns (uint) {
      return balances[holder];
  }  

  function approve(address _spender, uint256 _value) public returns (bool success) {
      approvals[msg.sender][_spender] +=_value;
      success = true;
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success){
    require(approvals[_from][msg.sender]>=_value);
    approvals[_from][msg.sender] -= _value;
    balances[_from]-=_value;
    balances[_to]+=_value;
    success=true;
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    require(balances[msg.sender]>=_value);
    balances[_to]+=_value;
    balances[msg.sender]-=_value;
    success=true;
  }
}

contract EarlyBirdToken is ERC20 {
  function EarlyBirdToken() public{
    balances[msg.sender] = 10000;
  }
}

contract LateComerToken is ERC20 {
  function LateComerToken() public{
    balances[msg.sender] = 10000;
  }
}

contract Scarcity is ERC20{

    address invertedBondingCurve;

    //modifier only IBC can call these
    function issue(uint _value, address to) public returns (bool) {
      require(msg.sender == invertedBondingCurve);
      balances[to]+=_value;
      return true;
    }

    function burn (uint _value, address from) public returns (bool) {
      require(msg.sender == invertedBondingCurve);
      require(balances[from]>=_value);
      balances[from] -=_value;
    }

    function setInvertedBonding (address ibc) public {
      if(invertedBondingCurve == address(0))
        invertedBondingCurve = ibc;
    }
}

contract InvertedBondingCurve { //S=1/10*A, V = 1/20*A^2 
  address scarcityAddress;
  mapping (address=>uint) tokenBalance;
  uint scarcityFees;
  address owner;
  mapping(address => uint) tokenOffsets;
  mapping (address => bool) validTokens;
  address tokenInjector;

  function changeOwner (address newOwner) public {
    if(owner == address(0) || owner == msg.sender)
      owner = newOwner;
  } 

 function changeInjector (address injector) public {
    if(tokenInjector == address(0) || tokenInjector == msg.sender)
      tokenInjector = injector;
  } 

  function setScarcityAddress(address scarcityToken) public {
      require(msg.sender == owner);
      scarcityAddress = scarcityToken;
  }

  function injectNewToken (address tokenContract,uint offset) public {
      tokenOffsets[tokenContract]= offset;
      validTokens[tokenContract] = true;
  }

  function sellTokenForScarcity(address tokenContract, uint tokenAmount) public {
    require(validTokens[tokenContract]=true);
    ERC20(tokenContract).transferFrom(msg.sender, this, tokenAmount);

    uint scarcityValueOfPurchase = getIntegralBetween2Points(tokenContract,tokenBalance[tokenContract]+tokenAmount, tokenBalance[tokenContract]);
    tokenBalance[tokenContract] = tokenBalance[tokenContract] + tokenAmount;

    //V = Ps.A
    //Ps = V/a
    //Ps*A = V

    Scarcity(scarcityAddress).issue(scarcityValueOfPurchase*99/100, msg.sender);
    scarcityFees+=scarcityValueOfPurchase/100;
  }

   function buyTokenWithScarcity (address tokenContract, uint scarcityAmount) public {
      //V = 1/2A^2(finish) - 1/2A^2(start)
      //let 1/2A^2(finish) =B
      //V-B = 1/2A**2;
      //(2(V-B))**0.5 = A
      require(validTokens[tokenContract]=true);

      uint scarcityValueOfExistingTokenStock = 
      getIntegralBetween2Points(tokenContract, tokenBalance[tokenContract], 0);
      uint tokenQuantityToSend = sqrt(2*(scarcityAmount - scarcityValueOfExistingTokenStock));
      require(tokenBalance[tokenContract]>tokenQuantityToSend);

      Scarcity(scarcityAddress).burn(scarcityAmount, msg.sender);

      tokenBalance[tokenContract] -= tokenQuantityToSend;

      ERC20(tokenContract).transfer(msg.sender,tokenQuantityToSend);
   }

    function withdrawScarcityFees () public {
        require(msg.sender == owner);
        ERC20(scarcityAddress).transfer(msg.sender,scarcityFees);
    }

    function sqrt(uint x) internal pure returns (uint y) {
      uint z = (x + 1) / 2;
      y = x;
      while (z < y) {
          y = z;
          z = (x / z + z) / 2;
      }
  }

     function getIntegralBetween2Points(address tokenContract, uint greater, uint lesser) private view returns(uint) {
         require(greater>=lesser);
         uint offset = tokenOffsets[tokenContract];
         return (greater**2)/2 + greater*offset - (lesser**2)/2 - lesser*offset;
       }
}
