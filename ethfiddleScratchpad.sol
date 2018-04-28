
//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.20;


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

contract InvertedBondingCurve { //Ps = 3x10^11*(A^-0.5)
  address scarcityAddress;
  mapping (address=>uint) tokenBalance;
  uint scarcityFees;
  address owner;
  mapping(address => uint) scalingFactor;
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

  function injectNewToken (address tokenContract,uint factor) public {
      scalingFactor[tokenContract]= factor;
      validTokens[tokenContract] = true;
  }

  function sellTokenForScarcity(address tokenContract, uint tokenAmount) public {
      ERC20(tokenContract).transferFrom(msg.sender,this,tokenAmount);
      uint scarcity = calculateScarcityBetween2Points(tokenContract,tokenBalance[tokenContract]+tokenAmount,tokenBalance[tokenContract]);
      Scarcity(scarcityAddress).issue(scarcity,msg.sender);
      tokenBalance[tokenContract]+=tokenAmount;
  }

   function buyTokenWithScarcity (address tokenContract, uint scarcityAmount) public {
     uint LHS = scarcityAmount/(3*(10**scalingFactor[tokenContract]));
     uint endBalance = (LHS - sqrt(tokenBalance[tokenContract]))**2;
     uint amountToSend = tokenBalance[tokenContract] - endBalance;
     ERC20(tokenContract).transfer(msg.sender,amountToSend);
     tokenBalance[tokenContract] = endBalance;
   }

    function withdrawScarcityFees () public {
        require(msg.sender == owner);
        ERC20(scarcityAddress).transfer(msg.sender,scarcityFees);
    }

      //for selling ERC for scarcity, use this
    function calculateScarcityBetween2Points (address tokenContract, uint A0, uint A1) public view returns (uint) {
        uint sqrtOfSmallerValue = A0==0?0:sqrt(A0);
        uint coefficient = 3*10**scalingFactor[tokenContract];
       return   coefficient*(sqrt(A1) - sqrtOfSmallerValue);
    }



    function sqrt(uint x) internal pure returns (uint y) {
      uint z = (x + 1) / 2;
      y = x;
      while (z < y) {
          y = z;
          z = (x / z + z) / 2;
      }
  }
}
