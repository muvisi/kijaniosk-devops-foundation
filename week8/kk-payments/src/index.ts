import http from "node:http";

const PORT = Number(process.env.PORT || 3001);
const VERSION = process.env.APP_VERSION || "1.0.0";

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: "healthy",
      service: "kk-payments",
      version: VERSION
    }));
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "Not Found" }));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`kk-payments listening on port ${PORT}`);
});

function shutdown() {
  console.log("Graceful shutdown initiated");

  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
