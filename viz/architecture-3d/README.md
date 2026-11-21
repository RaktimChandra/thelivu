# Thelivu 3D architecture explorer

An interactive 3D model of the whole system, built with Three.js and generated from `src/architecture.js`:
- the patient-app "house": core services, game SDK, the 7 domain rooms with their game slots, and the screens;
- the cloud: API and PostgreSQL with row-level security;
- the clinic portal;
- animated data flows between them.

It includes a guided tour for presentations.

```bash
npm install
npm run dev     # open http://localhost:5173
npm run build   # dist/index.html: one self-contained file (also copied to docs/architecture/)
```

`docs/architecture/thelivu-architecture.glb` is the same model as a standard glTF 2.0 file. Open it in Windows 3D Viewer, Blender, or https://gltf-viewer.donmccurdy.com. It's regenerated from the page with the "Download 3D file" button.

When a game's status changes, update `src/architecture.js` and rebuild.
