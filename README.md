# 🚀 Cross-Chain Rebase Token

A protocol that allows users to deposit into a vault and receive **rebase tokens** that represent their dynamically growing underlying balance.

## 🌱 How It Works

- Users **deposit tokens** into a vault.
- In return, they receive **rebase tokens** — a special ERC20 token whose `balanceOf` grows **linearly over time**.
- The growth is calculated based on the **interest rate at the time of deposit**, which stays fixed for each user.
- Interest is rewarded **on every interaction** like minting, burning, transferring — or even bridging.

## 💸 Dynamic Balance (Rebase)

- `balanceOf(address)` returns a **dynamic balance** that increases linearly based on:
  - The amount deposited (principal)
  - The user's fixed interest rate
  - Time elapsed since their last interaction

- Rebase logic ensures:
  - Early users benefit from higher interest.
  - Rewards scale with time, incentivizing longer deposits.
  - Interest rate **only decreases over time** — never increases.

## 🌉 Cross-Chain Bridging (via Chainlink CCIP)

- This project integrates **Chainlink CCIP** to bridge rebase tokens cross-chain.
- When bridging:
  - A user’s interest rate **travels with them** and remains fixed.
  - Accrued interest during bridging is **not earned** unless bridged back manually.
  - Bridging to L2 preserves rewards but **interest doesn't accrue during the bridging period**.

### Key Bridging Rules:
- 🔄 Only deposit/withdraw on L1.
- ⛓️ Tokens can be bridged to L2, but:
  - Interest **does not accrue** while on L2.
  - Accrued interest must be **bridged manually** back to the destination chain.
  - Early bridgers enjoy better rates, **rewarding early cross-chain adoption**.

## ✍️ Technical Highlights

- Rebase is handled via a custom ERC20 extension.
- `mintAccruedInterest()` is called on every user interaction to sync balances.
- Uses **per-user interest rate tracking** to avoid global recalculations.
- Interest is calculated using: principleBalance * (1 + interestRate * timeElapsed)

## 🧠 Notes

- 🏦 Assumes rewards are pre-funded into the contract.
- 📉 Interest rate **decreases discretely** over time.
- 🧊 The interest rate at deposit/bridge time **freezes per user**.
- 🌐 Users can only **deposit/withdraw on L1**.
- 💤 No interest is earned while tokens are in transit (bridging).
- 🔁 Bridged users must manually **bridge interest** accrued back to their destination chain.

## 📌 Use Cases
- Cross-chain **lending protocols**
- DeFi vaults with **time-based reward mechanics**
- Protocols that reward **early adopters**
- Gamified DeFi products with **dynamic interest scaling**

## 🧪 Code Quality

- ✅ **100% test coverage** using **Foundry’s forge coverage**
- 🔒 Covered all edge cases, rebase math, and bridging logic
- 🧬 Built with security-first testing: fuzzing, stateful testing, and custom scenarios

---

👨‍💻 Built as part of the **Cyfrin Updraft** course  
🔥 Proud to say this is my **most badass project yet**  
📈 Learning, building & breaking smart contracts one commit at a time  
🌍 Big things are coming — ZK, Optimism, and beyond!