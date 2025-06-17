# Bitcoin-Backed Options Protocol (BBOP)

A trust-minimized, collateral-backed protocol enabling users to create, exercise, and settle BTC-denominated CALL and PUT options on the Stacks blockchain. Built for compliance with Bitcoin value transfer and Layer-2 scaling principles.

## Overview

The Bitcoin-Backed Options Protocol (BBOP) empowers users to deposit synthetic BTC (sBTC), minting on-chain CALL and PUT options with fully-backed collateral. The protocol ensures secure, transparent, and decentralized options trading while maintaining strict collateralization requirements.

## Key Features

- **Dynamic BTC Price Oracle**: Real-time BTC price feeds with staleness protection
- **Configurable Parameters**: Adjustable collateralization ratios, fees, and expiry windows
- **Secure Lifecycle Management**: Complete option creation, exercise, and expiry flows
- **Transparent Storage**: On-chain tracking of balances, locked collateral, and option states
- **Trust-Minimized Design**: Fully collateralized options with automated settlement

## System Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Price Oracle  │    │  Options Core   │    │ User Interface  │
│                 │    │                 │    │                 │
│ • BTC Price     │───►│ • Option Logic  │◄───│ • Deposit sBTC  │
│ • Staleness     │    │ • Collateral    │    │ • Create Option │
│ • Validation    │    │ • Exercise      │    │ • Exercise      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Contract Architecture

The BBOP contract is structured into several key modules:

#### 1. Oracle System

- **Price Management**: Maintains current BTC price with timestamp validation
- **Staleness Protection**: Prevents execution with outdated price data
- **Oracle Authorization**: Restricts price updates to authorized addresses

#### 2. Options Engine

- **Option Creation**: Validates parameters and locks collateral
- **Exercise Logic**: Handles profit calculation and settlement
- **Expiry Management**: Automates collateral release for expired options

#### 3. Collateral Management

- **Balance Tracking**: Maintains user sBTC balances and locked collateral
- **Collateral Validation**: Ensures sufficient backing for all options
- **Automated Settlement**: Handles profit distribution and collateral release

#### 4. Administrative Controls

- **Parameter Configuration**: Adjustable fees, collateral ratios, and validity windows
- **Access Control**: Owner-only functions for protocol management

## Data Flow

### Option Creation Flow

```
User Request → Validate Parameters → Check Collateral → Lock Funds → Create Option → Return Option ID
```

1. **Parameter Validation**: Strike price, expiry, amount, and option type validation
2. **Collateral Check**: Verify user has sufficient sBTC balance
3. **Collateral Lock**: Transfer required collateral to locked state
4. **Option Registration**: Store option details in contract state
5. **ID Generation**: Return unique option identifier

### Option Exercise Flow

```
Exercise Request → Validate Authorization → Check Price → Calculate Profit → Settle → Update Status
```

1. **Authorization**: Verify caller is option holder
2. **Price Validation**: Ensure current BTC price is fresh and valid
3. **Profit Calculation**: Determine exercise value based on option type
4. **Settlement**: Transfer profits to option holder
5. **Status Update**: Mark option as exercised

### Option Expiry Flow

```
Expiry Request → Validate Expiry → Release Collateral → Update Status
```

1. **Expiry Validation**: Confirm option has passed expiry block height
2. **Collateral Release**: Return locked collateral to option creator
3. **Status Update**: Mark option as expired

## Configuration Parameters

### Protocol Limits

- **Maximum Fee**: 100% (10,000 basis points)
- **Maximum Collateral Ratio**: 1,000%
- **Minimum Deposit**: 1 sBTC (1,000 units)
- **Maximum Deposit**: 100,000,000,000 units
- **Minimum Validity Window**: 10 blocks
- **Maximum Validity Window**: 1,440 blocks (~24 hours)

### Default Settings

- **Minimum Collateral Ratio**: 150%
- **Platform Fee**: 0.1% (10 basis points)
- **Price Validity Window**: 150 blocks (~25 minutes)

## Error Handling

The protocol implements comprehensive error handling with specific error codes:

| Error Code | Description |
|------------|-------------|
| 100 | Not Authorized |
| 101 | Invalid Amount |
| 102 | Insufficient Balance |
| 103 | Option Not Found |
| 104 | Option Expired |
| 105 | Invalid Strike Price |
| 106 | Invalid Expiry |
| 107 | Insufficient Collateral |
| 108 | Option Not Exercisable |
| 109 | Stale Price |
| 110 | Invalid Price |
| 111 | Option Not Expired |
| 112 | Invalid Parameter |

## API Reference

### Public Functions

#### User Operations

- `deposit-sbtc(amount)` - Deposit sBTC to user balance
- `create-option(type, strike-price, expiry, amount)` - Create new option
- `exercise-option(option-id)` - Exercise an active option
- `expire-option(option-id)` - Expire an option past expiry

#### Oracle Operations

- `update-btc-price(new-price)` - Update BTC price (oracle only)

#### Administrative Functions

- `set-oracle-address(new-oracle)` - Update oracle address
- `set-price-validity-window(new-window)` - Configure price validity
- `set-platform-fee(new-fee)` - Update platform fee
- `set-min-collateral-ratio(new-ratio)` - Adjust collateral requirements

### Read-Only Functions

- `get-current-btc-price()` - Get current BTC price with staleness check
- `get-option(option-id)` - Retrieve option details
- `get-user-balance(user)` - Get user balance information
- `get-platform-fee()` - Get current platform fee

## Security Considerations

### Collateral Security

- All options are fully collateralized with locked sBTC
- Minimum 150% collateralization ratio prevents undercollateralization
- Automated collateral release on expiry

### Oracle Security

- Price staleness protection prevents execution with outdated data
- Authorized oracle addresses only
- Configurable validity windows for price data

### Access Control

- Contract owner controls for administrative functions
- Option holder verification for exercise operations
- Strict parameter validation for all inputs

## Usage Examples

### Creating a CALL Option

```clarity
(contract-call? .bbop create-option "CALL" u50000 u1000 u100)
```

### Exercising an Option

```clarity
(contract-call? .bbop exercise-option u1)
```

### Depositing sBTC

```clarity
(contract-call? .bbop deposit-sbtc u10000)
```

## Deployment Requirements

- Stacks blockchain compatible environment
- sBTC token integration for collateral
- Authorized BTC price oracle
- Administrative access for protocol management

## Contributing

This protocol is designed for production use on the Stacks blockchain. Contributions should focus on security, efficiency, and user experience improvements while maintaining the trust-minimized design principles.

## License

This protocol is released under appropriate licensing terms for blockchain deployment and use.
