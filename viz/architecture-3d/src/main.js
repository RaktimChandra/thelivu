// Thelivu · interactive 3D architecture explorer.
// The "house" metaphor the founder uses: the house and rooms are built; games are
// furniture that plugs into a domain's room. Everything is generated from
// architecture.js, so the model always matches the real repository.
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/addons/renderers/CSS2DRenderer.js";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";
import { STATUS, CORE, SDK, SCREENS, DOMAINS, CLOUD, PORTAL, TOUR } from "./architecture.js";

const app = document.getElementById("app");
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.outputColorSpace = THREE.SRGBColorSpace;
app.appendChild(renderer.domElement);
const labels = new CSS2DRenderer();
labels.domElement.className = "labels";
app.appendChild(labels.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xe8f0ee);
scene.fog = new THREE.Fog(0xe8f0ee, 45, 90);
const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 300);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI * 0.49;
controls.minDistance = 6;
controls.maxDistance = 70;

// Lights -----------------------------------------------------------------------
scene.add(new THREE.HemisphereLight(0xffffff, 0xb9c9c3, 1.1));
const sun = new THREE.DirectionalLight(0xfff4e0, 2.2);
sun.position.set(14, 26, 18);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -30, right: 30, top: 30, bottom: -30 });
scene.add(sun);

// Materials --------------------------------------------------------------------
const mat = {
  ground: new THREE.MeshStandardMaterial({ color: 0xdfe9e5, roughness: 0.95 }),
  slab: new THREE.MeshStandardMaterial({ color: 0xfbfcfb, roughness: 0.7, transparent: true, opacity: 0.78 }),
  pillar: new THREE.MeshStandardMaterial({ color: 0x16302b, roughness: 0.5 }),
  glass: new THREE.MeshPhysicalMaterial({ color: 0xd3eae4, transparent: true, opacity: 0.22, roughness: 0.1, metalness: 0, side: THREE.DoubleSide, depthWrite: false }),
  edge: new THREE.LineBasicMaterial({ color: 0x1e7568, transparent: true, opacity: 0.55 }),
  night: new THREE.MeshStandardMaterial({ color: 0x152f45, roughness: 0.6 }),
};
function statusMat(status) {
  const c = STATUS[status]?.color ?? 0x8aa0b8;
  return new THREE.MeshStandardMaterial({
    color: c, roughness: 0.45, metalness: 0.05,
    transparent: status === "planned", opacity: status === "planned" ? 0.35 : 1,
  });
}

const pickables = [];
const anchors = {};
const root = new THREE.Group();
root.name = "Thelivu architecture";
scene.add(root);

function label(text, cls, pos, parent = root) {
  const el = document.createElement("div");
  el.className = "lbl " + (cls || "");
  el.textContent = text;
  const o = new CSS2DObject(el);
  o.position.copy(pos);
  parent.add(o);
  return o;
}

function block(name, status, size, pos, info = {}, parent = root, radius = 0.12) {
  const g = new RoundedBoxGeometry(size[0], size[1], size[2], 3, Math.min(radius, Math.min(...size) / 2.2));
  const m = new THREE.Mesh(g, statusMat(status));
  m.position.set(pos[0], pos[1] + size[1] / 2, pos[2]);
  m.castShadow = status !== "planned";
  m.receiveShadow = true;
  m.name = name;
  m.userData = { name, status, ...info };
  parent.add(m);
  pickables.push(m);
  return m;
}

function slab(w, d, y, x, z, name) {
  const m = new THREE.Mesh(new RoundedBoxGeometry(w, 0.22, d, 2, 0.08), mat.slab);
  m.position.set(x, y + 0.11, z);
  m.receiveShadow = true;
  m.castShadow = true;
  m.name = name;
  root.add(m);
  const e = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(w, 0.22, d)), mat.edge);
  e.position.copy(m.position);
  root.add(e);
  return m;
}

// Ground ------------------------------------------------------------------------
const ground = new THREE.Mesh(new THREE.CircleGeometry(48, 64), mat.ground);
ground.rotation.x = -Math.PI / 2;
ground.position.y = -0.01;
ground.receiveShadow = true;
ground.name = "Ground";
root.add(ground);

// ================================================================= Patient app house
const H = { x: -7, z: 0, w: 11, d: 8.4 };
const FLOOR = { core: 0, sdk: 2.6, rooms: 5.2, roof: 8.0 };
for (const [k, y] of Object.entries(FLOOR)) slab(H.w, H.d, y, H.x, H.z, "Floor " + k);
for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
  const p = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, FLOOR.roof, 12), mat.pillar);
  p.position.set(H.x + sx * (H.w / 2 - 0.2), FLOOR.roof / 2, H.z + sz * (H.d / 2 - 0.2));
  p.castShadow = true;
  root.add(p);
}
label("PATIENT APP · on the phone, works offline", "bld", new THREE.Vector3(H.x, FLOOR.roof + 2.4, H.z));

function rowOf(items, y, z, info) {
  const n = items.length;
  const span = H.w - 1.6;
  items.forEach((it, i) => {
    const x = H.x - span / 2 + (span * (i + 0.5)) / n;
    block(it[0], it[1], [Math.min(1.25, span / n - 0.25), 0.9, 1.25], [x, y + 0.22, z], { path: it[2], what: it[3], ...info });
  });
}
rowOf(CORE, FLOOR.core, H.z + H.d / 2 - 1.2, { layer: "Core services" });
rowOf(SDK, FLOOR.sdk, H.z + H.d / 2 - 1.2, { layer: "Game Module SDK 1.0" });
anchors["floor:core"] = new THREE.Vector3(H.x, FLOOR.core + 1, H.z);
anchors["floor:sdk"] = new THREE.Vector3(H.x, FLOOR.sdk + 1, H.z);
label("Core services", "floor", new THREE.Vector3(H.x - H.w / 2 - 0.2, FLOOR.core + 0.9, H.z + H.d / 2));
label("Game SDK", "floor", new THREE.Vector3(H.x - H.w / 2 - 0.2, FLOOR.sdk + 0.9, H.z + H.d / 2));

// Domain rooms: 4 in front, 3 behind, each with 3 game slots (+ alternative).
const roomW = 2.45, roomD = 3.3, roomH = 1.85;
DOMAINS.forEach((dom, i) => {
  const front = i < 4;
  const col = front ? i : i - 4;
  const count = front ? 4 : 3;
  const x = H.x - ((count - 1) * (roomW + 0.15)) / 2 + col * (roomW + 0.15);
  const z = H.z + (front ? 2.0 : -1.9);
  const y = FLOOR.rooms + 0.22;
  const room = new THREE.Mesh(new THREE.BoxGeometry(roomW, roomH, roomD), mat.glass);
  room.position.set(x, y + roomH / 2, z);
  room.name = "Room " + dom.name;
  root.add(room);
  const e = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(roomW, roomH, roomD)), mat.edge);
  e.position.copy(room.position);
  root.add(e);
  anchors["domain:" + dom.id] = new THREE.Vector3(x, y + 0.8, z);
  label(dom.name, "room", new THREE.Vector3(x, y + roomH + (front ? 0.25 : 0.75), z));
  const games = dom.alt ? [...dom.games, dom.alt] : dom.games;
  games.forEach((g, k) => {
    const isAlt = dom.alt && k === 3;
    const gz = z - roomD / 2 + 0.55 + k * ((roomD - 1.1) / Math.max(1, games.length - 1));
    const h = g[1] === "planned" ? 0.35 : isAlt ? 0.55 : 0.8;
    block(g[0], g[1], [isAlt ? 0.7 : 0.95, h, 0.55], [x, y, gz],
      { layer: dom.name, path: g[2] ? "apps/patient-app/modules/" + g[2] : "", what: g[3] || "Empty slot: drop a module folder here and the registry picks it up.", alt: !!isAlt }, root, 0.08);
  });
});

// Roof: screens as standing phone panels.
SCREENS.forEach((s, i) => {
  const n = SCREENS.length;
  const x = H.x - (H.w - 1.4) / 2 + ((H.w - 1.4) * (i + 0.5)) / n;
  block(s, "built", [0.62, 1.15, 0.08], [x, FLOOR.roof + 0.22, H.z], { layer: "Screens (shell)", what: "Patient-facing screen in the Godot shell.", path: "apps/patient-app/shell/screens" }, root, 0.05);
});
anchors["roof"] = new THREE.Vector3(H.x, FLOOR.roof + 0.8, H.z);
label("Screens", "floor", new THREE.Vector3(H.x - H.w / 2 - 0.2, FLOOR.roof + 0.9, H.z + H.d / 2));

// ================================================================= Cloud
const C = { x: 8, z: -2 };
slab(8, 6.5, 0, C.x, C.z, "Cloud base");
label("CLOUD · API and database", "bld", new THREE.Vector3(C.x, 5.0, C.z));
const api = block(CLOUD[0][0], CLOUD[0][1], [3.2, 1.1, 1.6], [C.x - 1.6, 0.22, C.z + 1.6], { path: CLOUD[0][2], what: CLOUD[0][3], layer: "Cloud" });
const dbm = new THREE.Mesh(new THREE.CylinderGeometry(1.25, 1.25, 2.3, 48), statusMat("built"));
dbm.position.set(C.x + 1.9, 0.22 + 1.15, C.z - 0.6);
dbm.castShadow = true;
dbm.name = CLOUD[1][0];
dbm.userData = { name: CLOUD[1][0], status: "built", path: CLOUD[1][2], what: CLOUD[1][3], layer: "Cloud" };
root.add(dbm);
pickables.push(dbm);
for (let k = 1; k < 3; k++) {
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.26, 0.035, 8, 48), mat.slab);
  ring.rotation.x = Math.PI / 2;
  ring.position.set(dbm.position.x, 0.22 + k * 0.77, dbm.position.z);
  root.add(ring);
}
// Clinic walls inside the database (row-level security), shown as tinted slices on top.
["Clinic A", "Clinic B", "Clinic C"].forEach((nm, k) => {
  const s = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.1, 0.12, 32, 1, false, (k * 2 * Math.PI) / 3 + 0.05, (2 * Math.PI) / 3 - 0.1),
    new THREE.MeshStandardMaterial({ color: [0x1e7568, 0xd49a33, 0x4f6585][k], roughness: 0.4 }));
  s.position.set(dbm.position.x, 0.22 + 2.36, dbm.position.z);
  s.name = "RLS " + nm;
  root.add(s);
});
label("Each clinic walled off by row-level security", "note", new THREE.Vector3(C.x + 1.9, 3.2, C.z - 0.6));
block(CLOUD[2][0], CLOUD[2][1], [1.3, 0.8, 1.0], [C.x - 2.4, 0.22, C.z - 1.4], { path: CLOUD[2][2], what: CLOUD[2][3], layer: "Cloud" });
block(CLOUD[3][0], CLOUD[3][1], [1.3, 0.8, 1.0], [C.x - 0.8, 0.22, C.z - 1.4], { path: CLOUD[3][2], what: CLOUD[3][3], layer: "Cloud" });
block(CLOUD[4][0], CLOUD[4][1], [2.2, 1.4, 1.4], [C.x + 1.6, 0.22, C.z + 2.0], { path: CLOUD[4][2], what: CLOUD[4][3], layer: "Cloud" });
anchors["building:cloud"] = new THREE.Vector3(C.x, 1.2, C.z);

// ================================================================= Clinic portal
const P = { x: 6.5, z: 8.5 };
slab(7, 3.6, 0, P.x, P.z, "Portal base");
label("CLINIC PORTAL · clinicians and admins", "bld", new THREE.Vector3(P.x, 3.4, P.z));
PORTAL.forEach((p, i) => {
  const x = P.x - 2.4 + i * 1.6;
  block(p[0], p[1], [1.35, 1.6, 0.12], [x, 0.22, P.z + 0.6], { path: p[2], what: p[3], layer: "Clinic portal" }, root, 0.05);
});
anchors["building:portal"] = new THREE.Vector3(P.x, 1.0, P.z);

// ================================================================= Data flows
const flows = [];
function flow(a, b, color, lift = 3.5, speed = 0.16, count = 7) {
  const mid = a.clone().lerp(b, 0.5);
  mid.y = Math.max(a.y, b.y) + lift;
  const curve = new THREE.CatmullRomCurve3([a, mid, b]);
  const tube = new THREE.Mesh(new THREE.TubeGeometry(curve, 64, 0.025, 6), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.35 }));
  tube.name = "Flow";
  root.add(tube);
  const dots = [];
  for (let i = 0; i < count; i++) {
    const d = new THREE.Mesh(new THREE.SphereGeometry(0.09, 12, 12), new THREE.MeshBasicMaterial({ color }));
    d.userData.t = i / count;
    d.name = "Flow particle";
    root.add(d);
    dots.push(d);
  }
  flows.push({ curve, dots, speed, tube });
}
const telemetryPos = pickables.find((m) => m.name === "Telemetry queue").position.clone();
const storePos = pickables.find((m) => m.name === "Encrypted store").position.clone();
flow(telemetryPos, api.position.clone(), 0x1e7568, 4.5);
flow(api.position.clone(), dbm.position.clone().setY(2.2), 0x1e7568, 1.2, 0.3, 4);
flow(api.position.clone(), new THREE.Vector3(P.x, 1.6, P.z + 0.6), 0xd49a33, 2.5);
flow(new THREE.Vector3(P.x - 1, 1.6, P.z + 0.6), storePos, 0x4f6585, 6.5, 0.1, 6);

// ================================================================= UI wiring
const info = document.getElementById("info");
const tip = document.getElementById("tip");
let hovered = null;
let selected = null;
const ray = new THREE.Raycaster();
const mouse = new THREE.Vector2();

function setEmissive(m, on, color = 0x333333) {
  if (!m?.material?.emissive) return;
  m.material.emissive.setHex(on ? color : 0x000000);
}

function showInfo(u) {
  const st = STATUS[u.status] ?? STATUS.planned;
  info.innerHTML = `<div class="ihead"><span class="chip" style="background:#${st.color.toString(16).padStart(6, "0")}">${st.label}</span><button id="iclose" aria-label="Close">×</button></div>
    <h2>${u.name}</h2><div class="layer">${u.layer ?? ""}${u.alt ? " · alternative module" : ""}</div>
    <p>${u.what ?? ""}</p>${u.path ? `<code>${u.path}</code>` : ""}`;
  info.classList.add("open");
  document.getElementById("iclose").onclick = () => { info.classList.remove("open"); setEmissive(selected, false); selected = null; };
}

function pick(ev) {
  const r = renderer.domElement.getBoundingClientRect();
  mouse.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
  mouse.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
  ray.setFromCamera(mouse, camera);
  return ray.intersectObjects(pickables, false)[0]?.object ?? null;
}
renderer.domElement.addEventListener("pointermove", (ev) => {
  const o = pick(ev);
  if (o !== hovered) {
    if (hovered && hovered !== selected) setEmissive(hovered, false);
    hovered = o;
    if (o && o !== selected) setEmissive(o, true, 0x222222);
  }
  renderer.domElement.style.cursor = o ? "pointer" : "grab";
  if (o) {
    tip.textContent = o.userData.name;
    tip.style.left = ev.clientX + 14 + "px";
    tip.style.top = ev.clientY + 12 + "px";
    tip.style.opacity = 1;
  } else tip.style.opacity = 0;
});
let downAt = null;
renderer.domElement.addEventListener("pointerdown", (ev) => { downAt = [ev.clientX, ev.clientY]; });
renderer.domElement.addEventListener("pointerup", (ev) => {
  if (!downAt || Math.hypot(ev.clientX - downAt[0], ev.clientY - downAt[1]) > 6) return;
  const o = pick(ev);
  if (!o) return;
  if (selected) setEmissive(selected, false);
  selected = o;
  setEmissive(o, true, 0x3a2a00);
  showInfo(o.userData);
  flyTo(o.position.clone(), 7);
});

// Camera flights ------------------------------------------------------------------
const HOME_POS = new THREE.Vector3(-4, 17, 27);
const HOME_TARGET = new THREE.Vector3(0, 2.6, 1.5);
camera.position.copy(HOME_POS);
controls.target.copy(HOME_TARGET);
let flight = null;
function flyTo(target, dist = 10, dir = new THREE.Vector3(0.35, 0.55, 1).normalize(), dur = 1.4) {
  flight = {
    t: 0, dur,
    fromPos: camera.position.clone(), fromTarget: controls.target.clone(),
    toTarget: target.clone(), toPos: target.clone().add(dir.clone().multiplyScalar(dist)),
  };
}
const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

// Tour --------------------------------------------------------------------------------
const tourBox = document.getElementById("tour");
let step = -1;
function goStep(i) {
  step = (i + TOUR.length) % TOUR.length;
  const s = TOUR[step];
  if (s.target === "overview") {
    flight = { t: 0, dur: 1.6, fromPos: camera.position.clone(), fromTarget: controls.target.clone(), toPos: HOME_POS.clone(), toTarget: HOME_TARGET.clone() };
  } else {
    const dist = s.target.startsWith("domain") ? 7.5 : s.target.startsWith("building") ? 12 : 11;
    flyTo(anchors[s.target], dist);
  }
  tourBox.innerHTML = `<div class="tstep">${step + 1} / ${TOUR.length}</div><h3>${s.title}</h3><p>${s.text}</p>
    <div class="tbtns"><button id="tprev">Back</button><button id="tnext" class="primary">${step === TOUR.length - 1 ? "Finish" : "Next"}</button><button id="texit">Exit tour</button></div>`;
  tourBox.classList.add("open");
  document.getElementById("tprev").onclick = () => goStep(step - 1);
  document.getElementById("tnext").onclick = () => (step === TOUR.length - 1 ? endTour() : goStep(step + 1));
  document.getElementById("texit").onclick = endTour;
}
function endTour() {
  tourBox.classList.remove("open");
  step = -1;
}
document.getElementById("btn-tour").onclick = () => goStep(0);
document.getElementById("btn-home").onclick = () => { endTour(); flight = { t: 0, dur: 1.2, fromPos: camera.position.clone(), fromTarget: controls.target.clone(), toPos: HOME_POS.clone(), toTarget: HOME_TARGET.clone() }; };
let flowsOn = true;
document.getElementById("btn-flow").onclick = (e) => {
  flowsOn = !flowsOn;
  flows.forEach((f) => { f.tube.visible = flowsOn; f.dots.forEach((d) => (d.visible = flowsOn)); });
  e.currentTarget.classList.toggle("off", !flowsOn);
};
document.getElementById("btn-glb").onclick = () => exportGLB().then((buf) => {
  try {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([buf], { type: "model/gltf-binary" }));
    a.download = "thelivu-architecture.glb";
    a.click();
  } catch { /* downloads blocked in some viewers */ }
  info.innerHTML = `<div class="ihead"><span class="chip" style="background:#1e7568">3D file</span><button id="iclose" aria-label="Close">×</button></div>
    <h2>thelivu-architecture.glb</h2><p>If your viewer blocks downloads, the same file is in the repository at
    <code>docs/architecture/thelivu-architecture.glb</code> and opens in Windows 3D Viewer, Blender or any glTF viewer.</p>`;
  info.classList.add("open");
  document.getElementById("iclose").onclick = () => info.classList.remove("open");
});
window.addEventListener("keydown", (e) => {
  if (step < 0) return;
  if (e.key === "ArrowRight") goStep(step + 1);
  if (e.key === "ArrowLeft") goStep(step - 1);
  if (e.key === "Escape") endTour();
});

// Legend
document.getElementById("legend").innerHTML = Object.values(STATUS)
  .map((s) => `<span><i style="background:#${s.color.toString(16).padStart(6, "0")}"></i>${s.label}</span>`).join("") +
  `<span><i class="flow"></i>Data flow</span>`;

// glTF export (also used headlessly to produce docs/architecture/thelivu-architecture.glb)
export function exportGLB() {
  const exporter = new GLTFExporter();
  const clone = root.clone(true);
  const kill = [];
  clone.traverse((o) => { if (o.isCSS2DObject) kill.push(o); });
  kill.forEach((o) => o.removeFromParent());
  return exporter.parseAsync(clone, { binary: true, onlyVisible: true });
}
window.exportGLB = async () => {
  const buf = await exportGLB();
  let s = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
};

// Loop ------------------------------------------------------------------------------
function resize() {
  const w = app.clientWidth, h = app.clientHeight;
  renderer.setSize(w, h);
  labels.setSize(w, h);
  camera.aspect = w / h;
  camera.fov = w < 700 ? 55 : 42;
  camera.updateProjectionMatrix();
}
window.addEventListener("resize", resize);
resize();

const clock = new THREE.Clock();
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  if (flight) {
    flight.t += dt / flight.dur;
    const k = ease(Math.min(1, flight.t));
    camera.position.lerpVectors(flight.fromPos, flight.toPos, k);
    controls.target.lerpVectors(flight.fromTarget, flight.toTarget, k);
    if (flight.t >= 1) flight = null;
  }
  for (const f of flows) for (const d of f.dots) {
    d.userData.t = (d.userData.t + dt * f.speed) % 1;
    d.position.copy(f.curve.getPointAt(d.userData.t));
  }
  controls.update();
  renderer.render(scene, camera);
  labels.render(scene, camera);
  requestAnimationFrame(frame);
}
frame();
window.__ready = true;
