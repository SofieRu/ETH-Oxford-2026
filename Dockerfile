FROM node:20

WORKDIR /app

# Copy package files
COPY backend/tee-agent/package*.json ./

# Install dependencies
RUN npm ci

# Copy TypeScript source code
COPY backend/tee-agent/src ./src
COPY backend/tee-agent/tsconfig.json ./

# Copy environment configuration
COPY backend/tee-agent/.env ./.env

# Build TypeScript to JavaScript
RUN npm run build

# Create data directory for wallet storage
RUN mkdir -p /app/data

# Environment variable for wallet location
ENV WALLET_KEY_FILE=/app/data/wallet.enc

# Run the compiled JavaScript
CMD ["node", "dist/main.js"]
