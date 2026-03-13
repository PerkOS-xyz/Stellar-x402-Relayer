# PerkOS Stellar x402 Relayer

x402 payment facilitator for Stellar, powered by [OpenZeppelin Relayer](https://docs.openzeppelin.com/relayer).

Verifies and settles x402 payments on Stellar (USDC) so that PerkOS Stack can accept Stellar as a payment network alongside EVM chains.

## Architecture

```
┌─────────────┐     x402 request      ┌──────────────────┐     settle tx     ┌─────────────┐
│  PerkOS      │ ──────────────────▶  │  Stellar x402    │ ───────────────▶  │   Stellar   │
│  Stack       │ ◀──────────────────  │  Relayer         │ ◀───────────────  │   Network   │
│              │     verify/settle     │  (OZ Relayer +   │     tx result     │  (testnet/  │
│              │     response          │   x402 plugin)   │                   │   pubnet)   │
└─────────────┘                       └──────────────────┘                   └─────────────┘
                                             │
                                             ▼
                                       ┌──────────┐
                                       │  Redis   │
                                       └──────────┘
```

- **Stack** detects `stellar:*` network in x402 requests → proxies to this relayer
- **Relayer** verifies Soroban auth entries, settles payments on-chain
- **Relayer account** pays all Stellar network fees (~$0.00001/tx) — users never need XLM

## Endpoints

All routes via the plugin endpoint:

| Route | Method | Description |
|-------|--------|-------------|
| `/api/v1/plugins/x402-facilitator/call/verify` | POST | Verify payment payload |
| `/api/v1/plugins/x402-facilitator/call/settle` | POST | Settle payment on-chain |
| `/api/v1/plugins/x402-facilitator/call/supported` | GET/POST | List supported payment kinds |

## Prerequisites

- Docker & Docker Compose
- Rust toolchain (for generating keystore files)

## Quick Start

### 1. Install plugin dependencies

```bash
cd x402-facilitator
pnpm install
pnpm run build
cd ..
```

### 2. Generate relayer keys

```bash
# Clone OZ Relayer repo temporarily to use key generation tool
git clone https://github.com/OpenZeppelin/openzeppelin-relayer /tmp/oz-relayer

# Generate keystore (password must have uppercase, lowercase, number, special char)
cd /tmp/oz-relayer
cargo run --example create_key -- \
  --password 'YourSecurePass123!' \
  --output-dir /path/to/this/repo/config/keys \
  --filename local-signer.json

# Generate API key
cargo run --example generate_uuid

# Clean up
rm -rf /tmp/oz-relayer
```

### 3. Configure environment

```bash
cp .env.example .env
# Edit .env with your API_KEY and KEYSTORE_PASSPHRASE
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Get relayer address & fund it

```bash
# Get the relayer's Stellar address
curl -H "Authorization: Bearer <API_KEY>" \
  http://localhost:8080/api/v1/relayers/stellar-relayer

# Fund the relayer account with XLM (mainnet)
# The relayer needs a small XLM balance to pay network fees (~$0.00001/tx)
# Send ~10 XLM to the relayer address from any Stellar wallet
```

## Configuration

### Networks

- `stellar:pubnet` — **production (pre-configured)**
- `stellar:testnet` — for development (add to config when needed)

### Supported Assets

| Network | Asset | Contract |
|---------|-------|----------|
| pubnet | USDC | `CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI75` |
| testnet | USDC | `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA` |

## Integrating with PerkOS Stack

In Stack's `X402Service`, detect `stellar:*` networks and proxy to this relayer:

```typescript
// In X402Service.verify() and X402Service.settle()
if (network.startsWith('stellar:')) {
  const relayerUrl = process.env.STELLAR_RELAYER_URL; // e.g. http://relayer:8080
  const response = await fetch(
    `${relayerUrl}/api/v1/plugins/x402-facilitator/call/verify`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.STELLAR_RELAYER_API_KEY}`,
      },
      body: JSON.stringify(request),
    }
  );
  return response.json();
}
```

## Deployment

Target: **perkos-cloud-01** (`46.225.62.30`)

```bash
# On perkos-cloud-01
mkdir -p /opt/stellar-x402-relayer
cd /opt/stellar-x402-relayer
git clone https://github.com/PerkOS-xyz/Stellar-x402-Relayer.git .
cp .env.example .env
# Configure .env
docker compose up -d
```

## References

- [x402 on Stellar](https://stellar.org/blog/foundation-news/x402-on-stellar)
- [OZ Relayer x402 Facilitator Guide](https://docs.openzeppelin.com/relayer/guides/stellar-x402-facilitator-guide)
- [OZ x402 Facilitator Plugin](https://github.com/OpenZeppelin/relayer-plugin-x402-facilitator)
- [OZ Relayer Example](https://github.com/OpenZeppelin/openzeppelin-relayer/tree/main/examples/x402-facilitator-plugin)
- [x402 Protocol](https://github.com/coinbase/x402)

## License

MIT
