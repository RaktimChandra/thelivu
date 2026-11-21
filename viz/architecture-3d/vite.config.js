import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";
// One self-contained HTML file: easy to share, publish and open offline.
export default defineConfig({ plugins: [viteSingleFile()], build: { assetsInlineLimit: 100000000 } });
