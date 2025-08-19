# EAS Agreement Anchors

This repository contains a system for creating, managing, and verifying two-party agreements on top of the [Ethereum Attestation Service (EAS)](https://attest.sh/). It provides a standardized and secure way for a primary entity (such as a DAO, protocol, or individual) to enter into on-chain agreements with various counterparties.

The core of the system is the `AgreementAnchor` contract, which serves as an immutable, on-chain record of an agreement about some off-chain content, identified by a `bytes32` content hash.

## Table of Contents

- [EAS Agreement Anchors](#eas-agreement-anchors)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [How It Works](#how-it-works)
    - [Core Components](#core-components)
    - [Workflow](#workflow)
  - [Getting Started](#getting-started)
    - [Requirements](#requirements)
    - [Installation](#installation)
  - [Usage](#usage)
    - [Testing](#testing)
    - [Deployment](#deployment)
  - [Security Model](#security-model)

## Overview

The EAS-Anchor system is designed to solve the problem of creating formal, bilateral agreements on-chain. While EAS provides a primitive for making attestations, this system builds a higher-level abstraction for agreements where two signers are required.

The primary use case is for a single, canonical **Signer** (e.g., a DAO) that needs to enter into many standardized agreements with different **Counter-Signers**. The system ensures that:

1.  All agreements associated with the primary Signer are created through a single, controlled factory.
2.  The content of the agreement is set before attestations are made.
3.  The consent of each party is explicitly tracked via individual attestations.
4.  The agreement's lifecycle (attestation and revocation) is governed by a strict set of rules defined in a central resolver.

## How It Works

The system is composed of three main contracts that work together to manage the agreement lifecycle.

### Core Components

- **`AgreementResolver.sol`**: This is the logic layer of the system. It is deployed once for a canonical `signer`. It serves as a custom EAS [Schema Resolver](https://docs.attest.sh/docs/core-concepts/resolver), meaning its hooks (`onAttest`, `onRevoke`) are automatically called by the EAS contract whenever an attestation or revocation is made using its schema. It is responsible for enforcing most business rules.
- **`AgreementAnchorFactory.sol`**: Each `AgreementResolver` deploys its own private factory. This factory is responsible for creating all `AgreementAnchor` contracts associated with the resolver's primary `signer`. This ensures that the resolver only ever acts upon anchors that it has created, preventing unauthorized contracts from interacting with the system.
- **`AgreementAnchor.sol`**: This contract is the stateful representation of a single agreement. It stores the immutable details of the agreement (`contentHash`, `partyA`, `partyB`) and the state of each party's consent (their latest attestation UID and whether the agreement has been revoked). An `AgreementAnchor`'s address is used in the `recipient` field of an EAS attestation.

### Workflow

1.  **Deployment**: The primary `signer` deploys a single `AgreementResolver` contract. The resolver's constructor automatically deploys its own `AgreementAnchorFactory`.
2.  **Schema Registration**: A schema is registered on EAS (e.g., `bytes32 contentHash`) with the deployed `AgreementResolver` as its official resolver.
3.  **Agreement Creation**: When the `signer` and a `counterSigner` agree on some off-chain content (e.g., a legal document), they calculate its 32 byte hash. They then call `createAgreementAnchor` on the resolver's factory, creating a new `AgreementAnchor` contract for this specific agreement.
4.  **Attestation (Signing)**: Both parties "sign" the agreement by making an EAS attestation.
    - **Recipient**: The address of the newly created `AgreementAnchor`.
    - **Schema**: The UID of the registered schema.
    - **Data**: The `contentHash` of the agreement.
5.  **Validation**: The `onAttest` hook in the `AgreementResolver` is triggered. It validates that the attester is a party to the agreement, the anchor is legitimate, and the content hash matches. If valid, it updates the state of the `AgreementAnchor`.
6.  **Revocation**: If a party wishes to revoke their consent, they revoke their attestation through EAS. The `onRevoke` hook is triggered, and if the revocation corresponds to the latest attestation for that party, the `AgreementAnchor` is marked as revoked.

## Getting Started

### Requirements

- [Foundry](https://github.com/foundry-rs/foundry) / [Foundryup](https://github.com/foundry-rs/foundry#installation)

### Installation

To install dependencies, run:

```bash
forge install
```

## Usage

### Testing

This project uses Foundry for testing. To run the full test suite:

```bash
forge test
```

To see test coverage:

```bash
forge coverage
```

### Deployment

The repository includes scripts for deploying the `AgreementResolver` and registering its schema on EAS. These can be found in the `script/` directory.

To deploy to a network (e.g., Sepolia), first set the required environment variables in a `.env` file (see `.env.example`). Then, run the deployment script:

```bash
forge script script/sepolia/DeployAndRegisterSchema.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify -vvvv
```

## Security Model

The security of the system relies on a few key principles:

- **Single Authority**: The `AgreementResolver` is the single source of truth and authority for the business logic of all agreements created under its schema.
- **Factory-Controlled Anchors**: The resolver will _only_ process attestations and revocations for `AgreementAnchor` contracts that were deployed by its own internal factory. This prevents malicious actors from creating their own anchors and having the resolver interact with them.
- **EAS as the State Layer**: The system leverages the security and immutability of the core EAS contracts for all other management of attestations. The resolver acts as a "guard" layer on top of EAS.
