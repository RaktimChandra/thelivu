#!/usr/bin/env python3
"""Thelivu media pipeline: generate photorealistic human hands and faces with
open-licence models, then register them in the app's media manifest as DRAFT.

Nothing generated here is shown to patients until the clinical team validates it
and sets status to "approved" (docs/research/THL-RES-002-real-human-media.md).

Models (both Apache-2.0, commercial use allowed):
  * black-forest-labs/FLUX.1-schnell   text-to-image (hands, neutral faces)
  * Qwen/Qwen-Image-Edit-2509          identity-preserving expression edits

Usage (run from the repo root):
  # hosted, no GPU: set HF_TOKEN first (huggingface.co/settings/tokens)
  python tools/media/generate.py hands --backend hf-api
  # local NVIDIA GPU
  python tools/media/generate.py hands --backend local
  python tools/media/generate.py faces --backend local --identities f01,f02
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps" / "patient-app"
MEDIA = APP / "assets" / "media"
MANIFEST = MEDIA / "manifest.json"
SPECS = Path(__file__).resolve().parent / "specs"
STAGING = ROOT / "tools" / "media" / "out"     # all candidates (git-ignored)


# ---------------------------------------------------------------- backends
class Backend:
    def text_to_image(self, prompt: str, seed: int, size: tuple[int, int]):
        raise NotImplementedError

    def edit(self, image, prompt: str, seed: int):
        raise NotImplementedError


class HFApi(Backend):
    """Hugging Face Inference Providers. Needs HF_TOKEN in the environment."""

    def __init__(self, model: str, edit_model: str | None):
        from huggingface_hub import InferenceClient
        token = os.environ.get("HF_TOKEN")
        if not token:
            sys.exit("Set HF_TOKEN (a read token from huggingface.co/settings/tokens).")
        self.client = InferenceClient(token=token)
        self.model, self.edit_model = model, edit_model

    def text_to_image(self, prompt, seed, size):
        return self.client.text_to_image(prompt, model=self.model, width=size[0], height=size[1], seed=seed,
                                         num_inference_steps=4)

    def edit(self, image, prompt, seed):
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        return self.client.image_to_image(buf.getvalue(), prompt=prompt, model=self.edit_model, seed=seed)


class Local(Backend):
    """Diffusers on a local NVIDIA GPU, with CPU offload for 8-12 GB cards."""

    def __init__(self, model: str, edit_model: str | None):
        import torch
        self.torch = torch
        self.model_id, self.edit_id = model, edit_model
        self._t2i = self._edit = None

    def _gen(self, seed):
        return self.torch.Generator("cpu").manual_seed(seed)

    def text_to_image(self, prompt, seed, size):
        if self._t2i is None:
            from diffusers import FluxPipeline
            self._t2i = FluxPipeline.from_pretrained(self.model_id, torch_dtype=self.torch.bfloat16)
            self._t2i.enable_model_cpu_offload()
        return self._t2i(prompt, guidance_scale=0.0, num_inference_steps=4, max_sequence_length=256,
                         width=size[0], height=size[1], generator=self._gen(seed)).images[0]

    def edit(self, image, prompt, seed):
        if self._edit is None:
            from diffusers import QwenImageEditPlusPipeline
            self._edit = QwenImageEditPlusPipeline.from_pretrained(self.edit_id, torch_dtype=self.torch.bfloat16)
            self._edit.enable_model_cpu_offload()
        return self._edit(image=[image], prompt=prompt, num_inference_steps=40, true_cfg_scale=4.0,
                          generator=self._gen(seed)).images[0]


def backend(name: str, spec: dict) -> Backend:
    cls = HFApi if name == "hf-api" else Local
    return cls(spec["model"], spec.get("edit_model"))


# ---------------------------------------------------------------- helpers
def remove_bg(img):
    from rembg import remove
    return remove(img)


def save_webp(img, path: Path, quality=88):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", quality=quality, method=6)


def register(entries: list[dict]):
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_id = {a["id"]: a for a in data["assets"]}
    for e in entries:
        by_id[e["id"]] = {**by_id.get(e["id"], {}), **e}
    data["assets"] = sorted(by_id.values(), key=lambda a: a["id"])
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def stamp():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------- jobs
def job_hands(args):
    spec = json.loads((SPECS / "hands_v1.json").read_text(encoding="utf-8"))
    be = backend(args.backend, spec)
    entries = []
    for item in spec["items"]:
        if args.only and item["id"] not in args.only:
            continue
        prompt = spec["base_prompt"].format(side=item["side"], pose=item["pose"])
        for seed in item["seeds"][: args.candidates]:
            img = be.text_to_image(prompt, seed, tuple(spec["size"]))
            if spec.get("remove_background"):
                img = remove_bg(img)
            out = STAGING / f"{item['id']}__s{seed}.webp"
            save_webp(img, out)
            print("candidate", out.relative_to(ROOT))
        # The first seed is promoted as the draft in the app; reviewers may swap it.
        chosen = STAGING / f"{item['id']}__s{item['seeds'][0]}.webp"
        dest = MEDIA / f"{item['id']}.webp"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(chosen.read_bytes())
        entries.append({
            "id": item["id"], "file": f"res://assets/media/{item['id']}.webp", "kind": "hand",
            "source": "generated",
            "generator": {"model": spec["model"], "licence": spec["licence"], "prompt": prompt, "seed": item["seeds"][0]},
            "consent": "synthetic image; depicts no real person",
            "anchor": item.get("tip"), "status": "draft", "created": stamp(),
        })
    register(entries)
    print(f"registered {len(entries)} hand assets as draft in {MANIFEST.relative_to(ROOT)}")


def job_faces(args):
    spec = json.loads((SPECS / "faces_v1.json").read_text(encoding="utf-8"))
    be = backend(args.backend, spec)
    wanted = set(args.identities.split(",")) if args.identities else None
    entries = []
    for ident in spec["identities"]:
        if wanted and ident["id"] not in wanted:
            continue
        base_prompt = spec["base_prompt"].format(**ident)
        seed = 1000 + int(ident["id"][1:])
        neutral = be.text_to_image(base_prompt, seed, tuple(spec["size"]))
        nid = f"faces/{ident['id']}_neutral"
        save_webp(neutral, MEDIA / f"{nid}.webp")
        entries.append(_face_entry(spec, nid, ident, "neutral", "-", base_prompt, seed))
        for emo, desc in spec["expressions"].items():
            if emo == "neutral":
                continue
            for inten in spec["intensities"]:
                p = spec["expression_prompt"].format(expression=desc, intensity=inten)
                img = be.edit(neutral, p, seed)
                aid = f"faces/{ident['id']}_{emo}_{inten}"
                save_webp(img, MEDIA / f"{aid}.webp")
                entries.append(_face_entry(spec, aid, ident, emo, inten, p, seed))
                print("face", aid)
    register(entries)
    print(f"registered {len(entries)} face assets as draft; run the rater validation before approval")


def _face_entry(spec, aid, ident, emo, inten, prompt, seed):
    return {
        "id": aid, "file": f"res://assets/media/{aid}.webp", "kind": "face", "source": "generated",
        "generator": {"model": spec["model"], "edit_model": spec.get("edit_model"), "licence": spec["licence"],
                      "prompt": prompt, "seed": seed},
        "identity": {k: ident[k] for k in ("id", "age", "region", "sex", "skin")},
        "consent": "synthetic identity; depicts no real person",
        "intended": {"emotion": emo, "intensity": inten},
        "validation": {"raters": 0, "agreement": None, "date": None},
        "status": "draft", "created": stamp(),
    }


def job_approve(args):
    """Mark assets approved after validation (clinical sign-off is recorded in the manifest)."""
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    n = 0
    for a in data["assets"]:
        if a["id"] in args.ids:
            a["status"] = "approved"
            a["approved_by"] = args.by
            a["approved_at"] = stamp()
            n += 1
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"approved {n} assets")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="job", required=True)
    h = sub.add_parser("hands"); h.add_argument("--backend", choices=["hf-api", "local"], default="hf-api")
    h.add_argument("--candidates", type=int, default=4); h.add_argument("--only", nargs="*")
    f = sub.add_parser("faces"); f.add_argument("--backend", choices=["hf-api", "local"], default="local")
    f.add_argument("--identities", default="")
    a = sub.add_parser("approve"); a.add_argument("ids", nargs="+"); a.add_argument("--by", required=True)
    args = ap.parse_args()
    {"hands": job_hands, "faces": job_faces, "approve": job_approve}[args.job](args)


if __name__ == "__main__":
    main()
