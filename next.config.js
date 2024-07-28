const withNextra = require("nextra")({
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.tsx",
});

const nextConfig = withNextra({
  output: "standalone",
});

module.exports = nextConfig;
