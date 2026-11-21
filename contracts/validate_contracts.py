#!/usr/bin/env python3
"""Validate contracts and every module manifest / media manifest against them."""
import json, pathlib, sys
import jsonschema, yaml
from openapi_spec_validator import validate
ROOT = pathlib.Path(__file__).resolve().parents[1]
C = ROOT / "contracts"
errors = 0
validate(yaml.safe_load((C / "openapi.yaml").read_text()), base_uri=(C / "openapi.yaml").as_uri())
print("openapi.yaml: valid OpenAPI 3.1")
mod_schema = json.loads((C / "schemas/module.schema.json").read_text())
for m in sorted((ROOT / "apps/patient-app/modules").rglob("module.json")):
    try:
        jsonschema.validate(json.loads(m.read_text()), mod_schema)
        print("ok ", m.relative_to(ROOT))
    except jsonschema.ValidationError as e:
        errors += 1; print("ERR", m.relative_to(ROOT), e.message)
media = json.loads((C / "schemas/media-manifest.schema.json").read_text())
jsonschema.validate(json.loads((ROOT / "apps/patient-app/assets/media/manifest.json").read_text()), media)
print("ok  media manifest")
sys.exit(1 if errors else 0)
