
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

contract ValidTCR {
    mapping(address => bool) validToken;

  function addContract (address token) public {
      validToken[token] = true;
  }

  function isValid(address token) public view returns (bool) {
    return validToken[token];
  }

}

contract InvertedBondingCurve { //Pt = 10S, Pt = 8S
  address scarcityAddress;
  mapping (address=>uint) tokenReserve; //debit
  mapping (address=>uint) tokenScarcityObligations; //credit
  address owner;
  address tokenValidator;

  function changeOwner (address newOwner) public {
    if(owner == address(0) || owner == msg.sender)
      owner = newOwner;
  } 

 function changeInjector (address validator) public {
    if(tokenValidator == address(0) || tokenValidator == msg.sender)
      tokenValidator = validator;
  } 

  function setScarcityAddress(address scarcityToken) public {
      require(msg.sender == owner);
      scarcityAddress = scarcityToken;
  }

  function buyScarcity(address tokenContract, uint tokenAmount) public {
      require(ValidTCR(tokenValidator).isValid(tokenContract));
      uint finalTokens = tokenReserve[tokenContract] + tokenAmount;
      uint finalScarcity = sqrt(finalTokens/5);
      uint scarcityToPrint = finalScarcity - tokenScarcityObligations[tokenContract];
      require(scarcityToPrint > 0);
      //issue scarcity, take tokens
      Scarcity(scarcityAddress).issue(scarcityToPrint, msg.sender);
      ERC20(tokenContract).transferFrom(msg.sender,this,tokenAmount);

      //bookkeeping
      tokenScarcityObligations[tokenContract] = finalScarcity;
      tokenReserve[tokenContract] = finalTokens;
  }

  function sellScarcity (address tokenContract, uint scarcity) public {
      require(ValidTCR(tokenValidator).isValid(tokenContract));
      require(scarcity<=tokenScarcityObligations[tokenContract]);
      uint scarcityAfter = tokenScarcityObligations[tokenContract] - scarcity;
      uint tokenValueCurrently = 4*(tokenScarcityObligations[tokenContract]**2);
      uint tokensAfter = 4*(scarcityAfter**2);

      uint tokensToSendToUser = tokenValueCurrently - tokensAfter;
      require(tokensToSendToUser > 0);
      
      tokenReserve[tokenContract] =  tokenReserve[tokenContract]-tokensToSendToUser;
      tokenScarcityObligations[tokenContract] = scarcityAfter;

      Scarcity(scarcityAddress).burn(scarcity,msg.sender);
      ERC20(tokenContract).transfer(msg.sender,tokensToSendToUser);
  }

  function withdrawTokenSurplus(address tokenContract) public {
    require(msg.sender == owner);
    uint tokenSaleObligations =  4*(tokenScarcityObligations[tokenContract]**2);
    uint surplus = tokenReserve[tokenContract] - tokenSaleObligations;
    ERC20(tokenContract).transfer(owner,surplus);
  }

  function calculateTokenValue (uint scarcityAmount, uint coefficient, uint offset) public pure returns (uint) {
      //Pt = coefficientS + offset
      //V = 1/2*coefficient*S^2 +offset*S 
      return (coefficient/2)*(scarcityAmount**2) + offset*scarcityAmount;
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
