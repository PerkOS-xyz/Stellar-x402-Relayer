#!/bin/bash
set -e

echo "🚀 PerkOS Stellar x402 Relayer Setup"
echo "======================================"

# 1. Clone OZ Relayer (needed for Docker build + key generation)
if [ ! -d "openzeppelin-relayer" ]; then
  echo "📦 Cloning OpenZeppelin Relayer..."
  git clone https://github.com/OpenZeppelin/openzeppelin-relayer.git
else
  echo "✅ OpenZeppelin Relayer already cloned"
fi

# 2. Install plugin dependencies
echo "📦 Installing x402-facilitator plugin..."
cd x402-facilitator
pnpm install
pnpm run build
cd ..

# 3. Generate keys if not present
if [ ! -f "config/keys/local-signer.json" ]; then
  echo ""
  echo "🔑 Generating relayer keystore..."
  echo "   Enter a strong password (must include uppercase, lowercase, number, special char):"
  read -s KEYSTORE_PASS

  cd openzeppelin-relayer
  cargo run --example create_key -- \
    --password "$KEYSTORE_PASS" \
    --output-dir ../config/keys \
    --filename local-signer.json
  cd ..

  echo ""
  echo "✅ Keystore created at config/keys/local-signer.json"
else
  echo "✅ Keystore already exists"
fi

# 4. Generate API key if not in .env
if [ ! -f ".env" ]; then
  echo ""
  echo "🔑 Generating API key..."
  cd openzeppelin-relayer
  API_KEY=$(cargo run --example generate_uuid 2>/dev/null | tail -1)
  cd ..

  cp .env.example .env
  sed -i.bak "s/^API_KEY=$/API_KEY=$API_KEY/" .env
  rm -f .env.bak

  echo "   API Key: $API_KEY"
  echo "   ⚠️  Edit .env to set KEYSTORE_PASSPHRASE"
  echo ""
else
  echo "✅ .env already exists"
fi

echo ""
echo "🎉 Setup complete! Next steps:"
echo "   1. Edit .env with your KEYSTORE_PASSPHRASE"
echo "   2. Run: docker compose up -d"
echo "   3. Get relayer address: curl -H 'Authorization: Bearer <API_KEY>' http://localhost:8080/api/v1/relayers/stellar-relayer"
echo "   4. Fund on testnet: curl 'https://friendbot.stellar.org?addr=<ADDRESS>'"
