import { join } from "node:path";
import { projectRoot } from "../../../wiki/scripts/runtime.mjs";
import { createWikiServer, listen } from "../../../wiki/scripts/server.mjs";

// Показывает отдельную ревизию только на localhost, сохраняя доступ к файлам внутри её каталога.
const root = join(projectRoot, "docs/concepts/visual-polish-2026-10-13/v1");
const server = createWikiServer(root, { project: "moon-valley-art-review" });
const port = await listen(server, 4184);
console.log("ART REVIEW: http://127.0.0.1:" + port + "/");
process.on("SIGINT", () => server.close(() => process.exit(0)));
