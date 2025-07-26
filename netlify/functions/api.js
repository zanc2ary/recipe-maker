import serverless from "serverless-http";
import { createServer } from "../../server/index.js";

const app = createServer();
export const handler = serverless(app);
