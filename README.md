# CreditHive: Community-Based Lending Protocol

CreditHive is a decentralized lending protocol built on Stacks that leverages on-chain reputation and community governance. The protocol enables a trust-based lending system where community members can build reputation through active participation and responsible borrowing.

## Overview

CreditHive implements a unique lending mechanism where members' borrowing capacity is determined by their trust level within the community. Trust is earned through:
- Successfully repaying loans
- Participating in community governance
- Maintaining nectar deposits (staking)

## Key Features

### Trust-Based Lending
- Members start with a base trust level of 500 (out of 1000)
- Trust level determines borrowing eligibility
- Successful loan repayments increase trust level
- Defaults result in trust penalties

### Community Governance
- DAO-style decision making for trust level adjustments
- Members with high trust (700+) can participate in governance
- Proposals require minimum vote participation
- Democratic process for reputation appeals

### Dynamic Trust Scoring
- Multi-factor trust calculation
- Rewards for active community participation
- Penalties for protocol violations
- Capped maximum trust level of 1000

## Core Functions

### Member Management
```clarity
(define-public (join-hive (member principal)))
(define-public (update-hive-activity (member principal) (activity-points uint) (deposit-points uint)))
```

### Lending Operations
```clarity
(define-public (request-honey (amount uint)))
(define-public (return-honey))
(define-public (check-honey-status (member principal)))
```

### Governance
```clarity
(define-public (propose-trust-adjustment (subject-member principal) (proposed-level uint) (justification (string-ascii 256))))
(define-public (vote-on-motion (motion-id uint) (support bool)))
(define-public (implement-motion (motion-id uint)))
```

## Protocol Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| TRUST-THRESHOLD | 500 | Minimum trust level for borrowing |
| HONEY-POT-LIMIT | 1,000,000 | Maximum loan size (in microSTX) |
| HIVE-COUNCIL-THRESHOLD | 700 | Minimum trust level for governance participation |
| MOTION-DURATION | 1440 | Voting period length (in blocks) |
| VIOLATION-PENALTY | 100 | Trust deduction for defaults |
| MINIMUM-VOTES-NEEDED | 10 | Required votes for motion execution |

## Error Handling

The protocol implements comprehensive error handling with specific error codes:

- ERR-UNAUTHORIZED (u100): Action not permitted
- ERR-INVALID-LOAN-SIZE (u101): Loan amount exceeds limits
- ERR-INSUFFICIENT-FUNDS (u102): Insufficient balance
- ERR-POOR-STANDING (u103): Trust level too low
- ERR-EXISTING-LOAN (u104): Active loan exists
- ERR-INVALID-MOTION (u105): Invalid governance motion
- And more...

## Security Considerations

1. **Trust Level Management**
   - Trust levels are capped at 1000
   - Multiple validations for trust adjustments
   - Protected governance functions

2. **Loan Safety**
   - Single active loan policy
   - Automatic default detection
   - Trust-gated borrowing limits

3. **Governance Security**
   - Minimum participation thresholds
   - Time-locked voting periods
   - Protected execution mechanics

## Getting Started

1. Deploy the contract to the Stacks blockchain
2. Initialize member status using `join-hive`
3. Build trust through community participation
4. Participate in governance once eligible

## Usage Examples

### Joining the Hive
```clarity
(contract-call? .credithive join-hive tx-sender)
```

### Requesting a Loan
```clarity
(contract-call? .credithive request-honey u100000)
```

### Participating in Governance
```clarity
(contract-call? .credithive vote-on-motion u1 true)
```

## Contributing

Contributions are welcome! 