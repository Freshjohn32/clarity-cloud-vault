# CloudVault

A decentralized storage solution for businesses built on the Stacks blockchain. This contract enables businesses to:

- Register as storage providers
- List available storage space
- Accept storage requests
- Track storage usage
- Handle payments for storage services

## Features

- Decentralized storage provider registration
- Storage space management
- Automated billing and payments system
- Storage request handling
- Provider reputation system
- Payment tracking and provider earnings
- Automated payment scheduling

## Payment System

The new payment system includes:
- Pay-as-you-go storage pricing
- Automated payment tracking
- Provider earnings management
- Payment scheduling with 24-hour intervals
- Direct STX transfers between clients and providers

## Getting Started

To deploy and test the contract:

1. Install Clarinet
2. Clone this repository
3. Run `clarinet test` 
4. Deploy using `clarinet deploy`

## Making Payments

Clients can make payments using the `make-payment` function:
```clarity
(contract-call? .cloud_vault make-payment request-id)
```
