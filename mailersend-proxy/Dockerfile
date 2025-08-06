# Base image
FROM node:18-alpine

WORKDIR /usr/src/app


COPY package*.json ./
RUN npm install

# Bundle app source
COPY . .

# Expose port
EXPOSE 3000

# Start app
CMD [ "node", "server.js" ]
