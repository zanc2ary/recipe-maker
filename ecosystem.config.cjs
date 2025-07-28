module.exports = {
  apps: [
    {
      name: "fusion-starter",
      script: "./dist/server/node-build.mjs",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",
      env: {
        NODE_ENV: "production",
      },
    },
  ],
};
