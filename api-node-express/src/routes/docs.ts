import { readFileSync } from "node:fs";
import { Router } from "express";
import swaggerUi from "swagger-ui-express";
import { parse } from "yaml";

const spec = readFileSync(new URL("../../openapi.yaml", import.meta.url), "utf8");

export const docsRoutes = Router();

docsRoutes.get("/openapi.yaml", (_req, res) => {
  res.type("application/yaml").send(spec);
});
docsRoutes.use("/docs", swaggerUi.serve, swaggerUi.setup(parse(spec)));
