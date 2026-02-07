FROM node:20-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY bot.js strategy.js ./
CMD ["node", "bot.js"]