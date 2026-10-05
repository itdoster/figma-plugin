# Use the Bun image as the base image
FROM oven/bun:latest

# Set the working directory in the container
WORKDIR /app

# Copy dependency manifests for better layer caching
COPY package*.json bun.lock ./

RUN bun install

# Copy the rest of the source code
COPY . .

# Expose the port on which the API will listen
EXPOSE 3055

# Run the server when the container launches
CMD ["bun", "src/talk_to_figma_mcp/server.ts"]