#!/usr/bin/env python3
from __future__ import annotations

import json
import hashlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "design" / "approved" / "brand"
PRODUCTION = BRAND / "production"
RESOURCES = ROOT / "apps" / "macos" / "Sources" / "TazkleApp" / "Resources"
TOKENS = ROOT / "packages" / "design-system" / "Sources" / "TazkleDesignSystem" / "TazkleTokens.swift"
ICON = ROOT / "apps" / "macos" / "Config" / "Tazkle.icns"
ICON_HASH = ROOT / "apps" / "macos" / "Config" / "Tazkle.icns.source-sha256"


def fail(message: str) -> None:
    print(f"brand-consistency: {message}", file=sys.stderr)
    raise SystemExit(1)


def relative_luminance(value: str) -> float:
    channels = [
        int(value[index : index + 2], 16) / 255
        for index in (1, 3, 5)
    ]
    linear = [
        channel / 12.92
        if channel <= 0.03928
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in channels
    ]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast_ratio(first: str, second: str) -> float:
    first_luminance = relative_luminance(first)
    second_luminance = relative_luminance(second)
    lighter = max(first_luminance, second_luminance)
    darker = min(first_luminance, second_luminance)
    return (lighter + 0.05) / (darker + 0.05)


palette = json.loads((BRAND / "tazkle-palette.json").read_text())
brand_values = {value.upper() for value in palette["brand"].values()}
theme_values = {
    value.upper()
    for theme in palette["themes"].values()
    for value in theme.values()
}
semantic_resolved_values = {
    value.upper()
    for theme in palette["semanticResolved"].values()
    for value in theme.values()
}
allowed_svg_colors = brand_values | theme_values | semantic_resolved_values

for intent, reference in palette["semantic"].items():
    group, key = reference.split(".", maxsplit=1)
    if group != "brand" or key not in palette["brand"]:
        fail(f"la referencia semántica {intent} apunta a {reference}, que no existe")

for theme in ("dark", "light"):
    surfaces = (
        palette["themes"][theme]["canvas"],
        palette["themes"][theme]["panel"],
    )
    for intent, value in palette["semanticResolved"][theme].items():
        for surface in surfaces:
            ratio = contrast_ratio(value, surface)
            if ratio < 4.5:
                fail(
                    f"semanticResolved.{theme}.{intent} sólo alcanza "
                    f"{ratio:.2f}:1 sobre {surface}"
                )

asset_map = {
    "tazkle-mark.svg": PRODUCTION / "tazkle-mark.svg",
    "tazkle-mark-mono-dark.svg": PRODUCTION / "tazkle-mark-mono-dark.svg",
    "tazkle-wordmark-light.svg": PRODUCTION / "tazkle-wordmark-light.svg",
    "tazkle-wordmark-dark.svg": PRODUCTION / "tazkle-wordmark-dark.svg",
    "tazki-mascot.svg": BRAND / "tazki-mascot.svg",
}

for name, source in asset_map.items():
    destination = RESOURCES / name
    if not destination.exists() or destination.read_bytes() != source.read_bytes():
        fail(f"{name} no coincide con el activo aprobado")

if not ICON.exists() or not ICON_HASH.exists():
    fail("falta el icono nativo o su huella de origen")

expected_icon_hash = hashlib.sha256(
    (PRODUCTION / "tazkle-app-icon.svg").read_bytes()
).hexdigest()
if ICON_HASH.read_text().strip() != expected_icon_hash:
    fail("Tazkle.icns no corresponde al SVG aprobado; ejecuta scripts/generate-macos-icon.sh")

for asset in [*PRODUCTION.glob("*.svg"), BRAND / "tazki-mascot.svg"]:
    colors = {value.upper() for value in re.findall(r"#[0-9A-Fa-f]{6}", asset.read_text())}
    unexpected = colors - allowed_svg_colors
    if unexpected:
        fail(f"{asset.name} usa colores fuera de la paleta: {sorted(unexpected)}")

mark = (PRODUCTION / "tazkle-mark.svg").read_text()
if "viewBox=\"-84 -84 168 168\"" not in mark:
    fail("el isotipo principal perdió su encuadre canónico")
if "clip-path=\"url(#boundary)\"" not in mark:
    fail("el isotipo principal perdió el límite circular invisible")
for color in ("blue", "violet", "cyan", "amber", "outlineLight"):
    if palette["brand"][color].upper() not in mark.upper():
        fail(f"el isotipo principal no contiene brand.{color}")

swift_tokens = TOKENS.read_text()
for key in ("blue", "violet", "cyan", "amber", "green"):
    hex_without_hash = palette["brand"][key][1:].upper()
    if f"0x{hex_without_hash}" not in swift_tokens:
        fail(f"TazkleTokens.swift no contiene brand.{key}")

for theme in ("dark", "light"):
    for intent, value in palette["semanticResolved"][theme].items():
        hex_without_hash = value[1:].upper()
        if f"0x{hex_without_hash}" not in swift_tokens:
            fail(
                f"TazkleTokens.swift no contiene semanticResolved.{theme}.{intent}"
            )

banned_patterns = {
    r"TazkleColors\.(primary|relation|proposal|caution)\b": "aliases cromáticos antiguos",
    r"Color\.accentColor": "Color.accentColor fuera del sistema semántico",
    r"\.orange\b": "naranja del sistema",
    r"Color\.(red|yellow|green|blue|purple|pink|cyan|mint|teal|indigo|brown)\b": (
        "un color directo del sistema fuera de los tokens semánticos"
    ),
}
for source in (ROOT / "apps").rglob("*.swift"):
    content = source.read_text()
    for pattern, description in banned_patterns.items():
        if re.search(pattern, content):
            fail(f"{source.relative_to(ROOT)} todavía usa {description}")

print("brand-consistency: passed")
