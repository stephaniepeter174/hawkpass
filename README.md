# Hawkpass - Smart Hawker License System

A blockchain-based daily permit token system with real-time location tracking for street vendors and hawkers.

## 🎯 Overview

Hawkpass is a decentralized application built on the Stacks blockchain that enables municipal authorities to issue digital hawker licenses while allowing vendors to operate with transparent, time-bound permits. The system combines daily permit tokens with real-time location verification to ensure compliance and streamline hawker operations.

## ✨ Key Features

### 🏪 For Hawkers/Vendors
- **Daily Digital Permits**: Secure blockchain-based licenses valid for 24 hours
- **Location Registration**: Real-time GPS coordinate tracking and verification
- **Permit Status**: Instant verification of license validity and expiration
- **Compliance Tracking**: Historical record of permitted operations
- **Mobile-Friendly**: Easy permit renewal and location updates

### 🏛️ For Authorities
- **License Management**: Issue, renew, and revoke hawker permits
- **Real-Time Monitoring**: Track vendor locations and permit compliance
- **Revenue Collection**: Transparent fee collection through smart contracts
- **Violation Detection**: Automated alerts for expired permits or location violations
- **Audit Trail**: Immutable record of all license transactions

## 🏗️ Architecture

The system consists of two main smart contracts:

### 1. Hawker License Contract (`hawker-license.clar`)
- Issues daily permits with unique license IDs
- Manages permit lifecycle (issue, renew, revoke)
- Tracks permit fees and revenue
- Maintains hawker registry and compliance records

### 2. Location Registry Contract (`location-registry.clar`)
- Records and updates hawker GPS coordinates
- Validates location against permitted zones
- Tracks movement history and timing
- Provides real-time location verification

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) for testing
- Stacks wallet for deployment

### Installation

1. Clone the repository:
```bash
git clone https://github.com/stephaniepeter174/hawkpass.git
cd hawkpass
```

2. Install dependencies:
```bash
npm install
```

3. Check contracts:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## 📋 Usage

### Issuing a License
```clarity
(contract-call? .hawker-license issue-license 
  'SP1HAWKER123... ;; hawker address
  u1000000      ;; fee in microSTX
)
```

### Updating Location
```clarity
(contract-call? .location-registry update-location 
  u12345        ;; license ID
  u123456789    ;; latitude (scaled)
  u987654321    ;; longitude (scaled)
)
```

### Checking Permit Status
```clarity
(contract-call? .hawker-license get-license-info u12345)
```

## 🔧 Contract Functions

### Hawker License Contract
- `issue-license`: Create new daily permit
- `renew-license`: Extend existing permit
- `revoke-license`: Cancel permit (authority only)
- `get-license-info`: Retrieve permit details
- `is-license-valid`: Check permit validity
- `collect-fees`: Withdraw collected fees (authority only)

### Location Registry Contract
- `update-location`: Record new GPS coordinates
- `get-current-location`: Retrieve latest position
- `get-location-history`: View movement timeline
- `verify-location`: Validate coordinates
- `set-permitted-zones`: Define allowed areas (authority only)

## 💰 Fee Structure

- **Daily License Fee**: 1,000,000 microSTX (1 STX)
- **Renewal Fee**: 800,000 microSTX (0.8 STX)
- **Location Update**: Free (gas fees only)
- **Late Penalty**: 200,000 microSTX (0.2 STX)

## 🛡️ Security Features

- **Time-Based Validation**: Permits expire after 24 hours
- **Location Verification**: GPS coordinates validated against permitted zones
- **Authority Controls**: Only authorized addresses can issue/revoke licenses
- **Audit Trail**: All transactions recorded on blockchain
- **Anti-Fraud**: Unique license IDs prevent duplication

## 🌐 Future Enhancements

- [ ] Mobile app integration
- [ ] Photo verification of vendor setup
- [ ] Multi-language support
- [ ] Bulk license management
- [ ] Analytics dashboard for authorities
- [ ] Integration with payment systems
- [ ] Geofencing alerts
- [ ] Vendor rating system

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Clarinet Docs](https://docs.hiro.so/clarinet)
- **Issues**: [GitHub Issues](https://github.com/stephaniepeter174/hawkpass/issues)
- **Discord**: [Stacks Discord](https://discord.gg/stacks)

## 📞 Contact

**Project Maintainer**: stephaniepeter174
**Email**: stephaniepeter174@gmail.com

---

Built with ❤️ on the Stacks blockchain for transparent and efficient hawker license management.
