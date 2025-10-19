# Membership Referral Reward System

## Overview
Implements a comprehensive referral tracking system that enables the Sports Club to reward members who bring in new registrations. This feature incentivizes member growth through transparent referral bonuses and automated tracking.

## Technical Implementation

### Key Functions Added:
1. **register-referral(referee, referrer)** - Owner-only function to link new members with their referrers
2. **claim-referral-bonus(referrer, amount)** - Owner-controlled bonus distribution to referrers
3. **get-referral-info(member)** - Read-only function to query referral metadata

### Data Structures:
- **referrals map**: Tracks referee -> {referrer, bonus-accrued, claimed} relationships
- Maintains single-referrer-per-member constraint
- Integrates with existing error constant patterns (ERR-NOT-AUTHORIZED u401)

### Error Handling:
- ERR-ALREADY-REGISTERED (u410): Prevents duplicate referral registrations
- ERR-NO-REFERRAL-BONUS (u411): Validates bonus claims
- ERR-NOT-AUTHORIZED (u401): Enforces owner-only operations

## Testing & Validation
- ✅ Contract passes `clarinet check` syntax validation
- ✅ All npm tests successful
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Clarity v3 compliant with proper type handling and error constants
- ✅ Line endings normalized to LF across all files
