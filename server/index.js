import "dotenv/config";
import express from "express";
import cors from "cors";
import { handleDemo } from "./routes/demo.js";
import { getRecipeRecommendations } from "./routes/recipes.js";
import { handleLogin, handleLogout } from "./routes/auth.js";

export function createServer() {
  const app = express();

  // Middleware
  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Example API routes
  app.get("/api/ping", (_req, res) => {
    const ping = process.env.PING_MESSAGE ?? "ping";
    res.json({ message: ping });
  });

  app.get("/api/demo", handleDemo);
  app.post("/api/recipes/recommend", getRecipeRecommendations);

  // Authentication routes
  app.post("/api/auth/login", handleLogin);
  app.post("/api/auth/logout", handleLogout);

  return app;
}
