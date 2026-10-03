import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import type { FastifyPluginAsync } from "fastify";

const SPEC_PATH = fileURLToPath(new URL("../../openapi.yaml", import.meta.url));

export const docsRoutes: FastifyPluginAsync = async (app) => {
  const spec = await readFile(SPEC_PATH, "utf8");

  await app.register(swagger, { mode: "static", specification: { path: SPEC_PATH, baseDir: "" } });
  await app.register(swaggerUi, { routePrefix: "/docs" });

  app.get("/openapi.yaml", (_req, reply) => reply.type("application/yaml").send(spec));
};
