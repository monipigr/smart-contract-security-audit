# Blockchain Security Vulnerabilities Demo

## Overview

This project demonstrates three critical blockchain security vulnerabilities through practical implementation and theoretical analysis. The main focus is a **reentrancy attack** simulation using a vulnerable banking contract, complemented by comprehensive test coverage. Additionally, it provides in-depth theoretical explanations of **oracle manipulation** and **slippage attacks**, complete with prevention strategies and visual diagrams to enhance understanding of these common DeFi exploitation vectors.

## Reentrancy Attack

### What is a Reentrancy Attack?

A **reentrancy attack** occurs when a malicious contract calls back into the vulnerable contract before the first function call is completed. This happens when:

1. Contract A calls Contract B
2. Contract B calls back into Contract A before the original call finishes
3. Contract A's state hasn't been updated yet, allowing exploitation

### The Vulnerability

In our `SimpleBank` contract, the vulnerability exists in the `withdraw()` function:

```solidity
function withdraw() public {
    require(userBalance[msg.sender] >= 1 ether, "User has not enough balance");
    require(address(this).balance > 0, "Bank is rekt");

    // 🚨 VULNERABLE: External call before state update
    (bool success, ) = msg.sender.call{value: userBalance[msg.sender]}("");
    require(success, "Fail");

    // State update happens AFTER external call
    userBalance[msg.sender] = 0;
}
```

### Attack Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌────────────────────┐
│   SimpleBank    │    │    Attacker     │    │  Attack Flow       │
│                 │    │                 │    │                    │
│ Balance: 20 ETH │    │ Balance: 2 ETH  │    │ 1. Deposit 2ETH    │
│ User: 20 ETH    │◄──►│                 │────┤ 2. Call withdraw   │
│ Attacker: 0 ETH │    │                 │    │ 3. Receive hook    │
└─────────────────┘    └─────────────────┘    │ 4. Re-call withdraw│
                                              │ 5. Drain all funds │
                       ┌─────────────────┐    └────────────────────┘
                       │    Result       │
                       │                 │
                       │ Bank: 0 ETH     │
                       │ Attacker: 22ETH │
                       │ User: Lost 20ETH│
                       └─────────────────┘
```

### Prevention Strategies

1. **Checks-Effects-Interactions Pattern**:

```solidity
function withdraw() public {
    // CHECK: Validate if allowed to withdraw
    require(userBalance[msg.sender] >= 1 ether, "Insufficient balance");

    // EFFECT: Update state FIRST
    uint256 amount = userBalance[msg.sender];
    userBalance[msg.sender] = 0;

    // INTERACTION: External call LAST
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

2. **ReentrancyGuard Modifier**:

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleBank is ReentrancyGuard {
    function withdraw() public nonReentrant {
        // Function logic here
    }
}
```

3. **Pull over Push Pattern**:

```solidity
mapping(address => uint256) public pendingWithdrawals;

function withdraw() public {
    pendingWithdrawals[msg.sender] = userBalance[msg.sender];
    userBalance[msg.sender] = 0;
}

function claimWithdrawal() public {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
}
```

### Test Coverage

The project includes comprehensive test coverage:

- ✅ **Deposit functionality** with edge cases
- ✅ **Withdraw functionality** with proper validation
- ✅ **Attack simulation** that drains all funds
- ✅ **Balance verification** before and after attack

**Key Test: Attack Simulation**

```solidity
function test_attack() public {
    // User deposits 20 ether
    vm.deal(user, 20 ether);
    vm.prank(user);
    simpleBank.deposit{value: 20 ether}();

    // Attacker executes attack with 2 ether
    vm.deal(address(attacker), 2 ether);
    vm.prank(address(attacker));
    attacker.attack{value: 2 ether}();

    // Verify all funds drained
    assert(simpleBank.totalBalance() == 0);
}
```

---

## Oracle Manipulation

### What is an Oracle?

An **oracle** is a bridge between the real world and smart contracts. Smart contracts cannot access external data directly - they only know about their own state and other smart contracts they can interface with. If a smart contract needs real-world data (like ETH price, weather data, or sports results), it must rely on an oracle.

**Example**: A smart contract handling bets on football matches cannot know the match result by itself. It needs an oracle to provide this external information.

### What is Oracle Manipulation?

**Oracle manipulation** occurs when the oracle provides incorrect data, either accidentally or maliciously. This can have catastrophic consequences since smart contracts make critical decisions based on this data.

**Example Scenario**:

- Real ETH price: $3,000
- Manipulated oracle reports: $5,000
- Result: All calculations in dependent smart contracts use the wrong price, leading to incorrect token distributions and potential financial losses

### Why Do Oracles Get Manipulated?

1. **Technical Malfunction**: Oracle may be broken or misconfigured
2. **Malicious Actor**: Someone with control over the oracle acts in bad faith for personal gain
3. **DEX Pool Manipulation**: Some applications use DEX pools (like Uniswap ETH/USDC) as price oracles

### Attack Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Real World    │    │   Centralized   │    │   DeFi Protocol │
│                 │    │     Oracle      │    │                 │
│ ETH = $3,000    │    │                 │    │ Betting/Lending │
│                 │────┤ Reports: $5,000 │────┤ Contract        │
│ Actual Price    │    │ (Manipulated)   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                ▲                        │
┌─────────────────┐             │                        ▼
│   DEX Pool      │             │              ┌─────────────────┐
│                 │             │              │     Result      │
│ ETH/USDC Pool   │─────────────┘              │                 │
│ Price manipulated             │              │ Wrong payouts   │
│ by large trade  │                            │ User losses     │
└─────────────────┘                            │ Protocol risk   │
                                               └─────────────────┘
```

#### DEX Pool Manipulation Example:

1. **Inject large amount** of ETH into ETH/USDC pool
2. **Price temporarily changes** due to pool imbalance
3. **Smart contract reads** manipulated price at that exact moment
4. **Arbitrage bots** eventually restore correct price, but damage is done

This manipulation is temporary due to arbitrage, but can be devastating if it occurs during a critical transaction.

---

## Slippage Attack

### Understanding the Mempool

Before understanding slippage, we need to understand how blockchain transactions work:

1. **User submits transaction** → Goes to **mempool** (waiting pool)
2. **Validators select transactions** from mempool based on **gas fees** (not FIFO)
3. **Higher gas = higher priority** → Transaction included in next block

### What is Slippage?

**Slippage** is the difference between the **expected tokens to receive** and the **tokens actually received** when performing a token swap.

**Example Scenario**:

- You want to swap 1 ETH for USDC on Uniswap
- Frontend shows: "You will receive 3,000 USDC"
- You click "Execute" → Transaction goes to mempool
- **Before your transaction is included**, someone else's transaction modifies the pool
- **Result**: You receive 2,998 USDC instead of 3,000 USDC
- **Slippage**: $2

### How Slippage Attacks Work

#### **Front-Running Attack**

1. **Attacker sees your transaction** in mempool (1 ETH → USDC swap)
2. **Attacker pays higher gas** to get included first
3. **Attacker's transaction** manipulates ETH/USDC pool (adds massive USDC)
4. **Pool balance changes** → ETH price drops to $500
5. **Your transaction executes** → You get 500 USDC instead of 3,000 USDC
6. **Attacker profits** from the price manipulation

#### **Sandwich Attack**

A **sandwich attack** combines two front-running attacks:

1. **Front-run**: Manipulate price DOWN before your transaction
2. **Your transaction**: Executes at manipulated price
3. **Back-run**: Restore price balance after your transaction
4. **Your transaction is "sandwiched"** between two manipulated transactions

### Attack Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mempool       │    │   Sandwich      │    │   DEX Pool      │
│                 │    │   Attacker      │    │   ETH/USDC      │
│ User's TX:      │    │                 │    │                 │
│ 1 ETH → 3000$   │◄──►│ 1. Sees user TX │    │ Balance: Normal │
│                 │    │ 2. Front-run    │◄──►│ Adds USDC       │
└─────────────────┘    │    (Higher gas) │    │ ETH = $500      │
          ▲            │ 3. User TX exec │    └─────────────────┘
          │            │    (Bad price)  │              │
          │            │ 4. Back-run     │              ▼
┌─────────────────┐    │    (Restore)    │    ┌─────────────────┐
│    Result       │◄───┤                 │    │   Price Impact  │
│                 │    │ 5. Extract MEV  │    │                 │
│ User gets: 500$ │    │                 │    │ 3000$ → 500$    │
│ Expected: 3000$ │    │                 │    │ → 3000$ (after) │
│ Loss: $2500     │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Prevention Strategies

The two main parameters to protect against slippage attacks:

#### **1. amountOutMin - Minimum Output Protection**

```solidity
function protectedSwap(
    uint256 amountIn,
    uint256 amountOutMin, // Must be calculated OFF-CHAIN
    address[] memory path,
    uint256 deadline
) external {
    uint256 amountOut = uniswap.swapExactTokensForTokens(
        amountIn,
        amountOutMin, // Minimum tokens you're willing to accept
        path,
        msg.sender,
        deadline
    );

    // If actual output < amountOutMin, transaction reverts
}
```

**Why OFF-CHAIN calculation?**

- You CANNOT calculate `amountOutMin` inside the smart contract
- Even calling Uniswap's `quote()` function happens on-chain
- Must be calculated in frontend before transaction submission

#### **2. deadline - Time Limit Protection**

```solidity
function swapWithDeadline(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] memory path,
    uint256 deadline // Maximum time willing to wait
) external {
    require(block.timestamp <= deadline, "Transaction expired");

    uniswap.swapExactTokensForTokens(
        amountIn,
        amountOutMin,
        path,
        msg.sender,
        deadline
    );
}
```

**Why deadline matters?**

- If attacker pays higher gas, your transaction waits longer in mempool
- Longer wait = more time for price manipulation
- Deadline protects by reverting if transaction takes too long

#### **3. Complete Protection Example**

```solidity
// Frontend calculates: if expecting 3000 USDC, set minimum to 2970 (1% slippage tolerance)
uint256 amountOutMin = expectedAmount * 99 / 100; // 1% tolerance
uint256 deadline = block.timestamp + 300; // 5 minutes max

uniswap.swapExactTokensForTokens(
    1 ether,           // amountIn
    amountOutMin,      // minimum acceptable output
    path,              // [WETH, USDC]
    msg.sender,        // recipient
    deadline           // time limit
);
```

## Technologies Used

- **Solidity ^0.8.24**
- **Foundry** for testing and development
- **OpenZeppelin** (recommended for production)

## Learning Resources

- [Smart Contract Security Field Guide](https://scsfg.io/hackers//)
- [DeFiHack Analysis](https://defihack.xyz/)
- [Foundry Documentation](https://book.getfoundry.sh/)

---

_This project is for educational purposes only. Never deploy vulnerable contracts to mainnet._
