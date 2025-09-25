const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send(`
    <h1>Hello Docker!</h1>
    <p>This is a simple Node.js app running in a Docker container.</p>
    <p>Current time: ${new Date().toISOString()}</p>
  `);
});

app.listen(port, () => {
  console.log(`App running at http://localhost:${port}`);
});
