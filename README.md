# 🏈 Sports Club Membership Smart Contract

A token-gated membership system for sports clubs built on the Stacks blockchain. Members receive NFTs representing their membership tier and earn club points for exclusive benefits.

## 🌟 Features

- **🎫 NFT-Based Memberships**: Unique membership tokens with three tiers
- **🗳️ On-Chain Governance**: Token-weighted voting on club proposals  
- **🏆 Rewards System**: Monthly club points based on membership tier
- **⬆️ Tier Upgrades**: Seamless membership upgrades with price difference
- **📅 Automatic Expiry**: Time-based membership validity (1 year)
- **🔄 Transferable**: Members can transfer their membership NFTs

## 🎯 Membership Tiers

| Tier | Price | Monthly Points | Benefits |
|------|-------|---------------|----------|
| **Basic** 🥉 | 1 STX | 100 points | Gym access, 1 guest pass |
| **Premium** 🥈 | 2.5 STX | 300 points | Gym + Pool access, 3 guest passes, priority booking |
| **VIP** 🥇 | 5 STX | 600 points | Full access (gym, pool, spa), 5 guest passes, exclusive events |

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd Sports-Club-Membership
clarinet check
```

### Testing

```bash
clarinet test
```

## 📖 Usage Guide

### 🎫 Minting Memberships

Only the contract owner can mint new memberships:

```clarity
(contract-call? .membership mint-membership "premium" 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### 🔄 Renewing Memberships

Members can renew their own memberships:

```clarity
(contract-call? .membership renew-membership u1)
```

### 🏆 Claiming Monthly Points

Members can claim points once per month (4320 blocks ≈ 30 days):

```clarity
(contract-call? .membership claim-monthly-points)
```

### 📝 Creating Proposals

Any member with voting rights can create proposals:

```clarity
(contract-call? .membership create-proposal 
    "Add New Equipment" 
    "Purchase new rowing machines for the gym" 
    "equipment")
```

### 🗳️ Voting on Proposals

Members vote with their tier-based voting power:

```clarity
(contract-call? .membership vote-on-proposal u1 true)
```

### ⬆️ Upgrading Memberships

Members can upgrade to higher tiers by paying the difference:

```clarity
(contract-call? .membership upgrade-membership u1 "vip")
```

### 🔄 Transferring Memberships

Members can transfer their NFT to another address:

```clarity
(contract-call? .membership transfer-membership u1 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

## 🔍 Read-Only Functions

### Check Membership Info
```clarity
(contract-call? .membership get-membership-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Check Voting Rights
```clarity
(contract-call? .membership has-voting-rights 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### View Proposal Details
```clarity
(contract-call? .membership get-proposal-info u1)
```

### Check Membership Benefits
```clarity
(contract-call? .membership get-membership-benefits u1)
```

### View Club Statistics
```clarity
(contract-call? .membership get-club-stats)
```

### Check Membership Expiry
```clarity
(contract-call? .membership check-membership-expiry u1)
```

## 🏗️ Contract Architecture

The contract implements:

- **NFT Token**: `membership-nft` for unique membership certificates
- **Fungible Token**: `club-points` for rewards and benefits
- **Membership Management**: Tiered system with automatic expiry
- **Governance System**: Proposal creation and voting with weighted votes
- **Benefits Tracking**: Detailed access rights per membership tier

## 🔒 Security Features

- Owner-only minting prevents unauthorized memberships
- Membership validation ensures only active members can vote
- Time-based expiry prevents indefinite access
- Voting period limits prevent manipulation
- Transfer restrictions maintain membership integrity

## 🛠️ Error Codes

| Code | Description |
|------|-------------|
| `u401` | Not authorized |
| `u402` | Insufficient payment |
| `u403` | Voting period ended |
| `u404` | Membership/proposal not found |
| `u405` | No voting rights |
| `u406` | Proposal not active |
| `u407` | Invalid tier |
| `u409` | Already voted |

## 📊 Club Benefits System

Each membership tier unlocks progressive benefits:

### 🥉 Basic Tier
- ✅ Gym access
- ❌ Pool access
- ❌ Spa access
- 🎫 1 guest pass/month
- ❌ Priority booking
- ❌ Exclusive events

### 🥈 Premium Tier  
- ✅ Gym access
- ✅ Pool access
- ❌ Spa access
- 🎫 3 guest passes/month
- ✅ Priority booking
- ❌ Exclusive events

### 🥇 VIP Tier
- ✅ Gym access
- ✅ Pool access
- ✅ Spa access
- 🎫 5 guest passes/month
- ✅ Priority booking
- ✅ Exclusive events

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes with `clarinet check`
4. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details

---

Built with ❤️ on Stacks blockchain 🔗
