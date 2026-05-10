"""
ENH-018 Hilal Watch — map rendering mockups generator.

Generates two PNG mockups comparing the visibility-map rendering options
considered for EPIC-0011 (see docs/RELEASE_PLAN.md):

  - 2026-05-10-hilal-map-option2-canvas-png.png — SwiftUI Canvas + bundled
    equirectangular outline PNG (rejected approach)
  - 2026-05-10-hilal-map-option3-mapkit.png — MapKit MKPolygonRenderer on
    a Mercator base map (chosen approach for v1)

The PNGs are .gitignored because the upload proxy in this environment
rejects binary content. Regenerate them locally any time:

    pip install Pillow matplotlib cartopy   # one-time
    python3 docs/mockups/gen_hilal_mockups.py

The S-curve visibility cells are synthesised (not real Odeh data) — the
script only exists to communicate the visual language of each rendering
approach. Real Odeh values will be computed by the Swift port of
astronomy-engine v2 once EPIC-0011 enters implementation.
"""
import math
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.collections import PatchCollection
import numpy as np
import cartopy.crs as ccrs
import cartopy.feature as cfeature

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# OmegaHilalSighting / moonsighting.com colours
RGBA_D = (205/255, 35/255, 35/255, 0.78)
RGBA_C = (105/255, 110/255, 120/255, 0.72)
RGBA_B = (5/255, 158/255, 193/255, 0.82)
RGBA_A = (22/255, 125/255, 52/255, 0.86)
CAT_COLORS = [None, RGBA_D, RGBA_C, RGBA_B, RGBA_A]

LEGEND_LABELS = [
    ("D — Optical aid only", (205/255, 35/255, 35/255)),
    ("C — Optical aid to locate", (105/255, 110/255, 120/255)),
    ("B — Good conditions", (5/255, 158/255, 193/255)),
    ("A — Easily visible naked eye", (22/255, 125/255, 52/255)),
]


def cat_at(lon, lat, evening=29):
    """Simulated S-curve visibility band — illustrative, not real Odeh data."""
    if evening == 29:
        center_lon = -40 + 0.45 * lat - 0.0006 * lat ** 3
        band_width = 80
        peak_cat = 3.5
    else:
        center_lon = -110 + 0.35 * lat - 0.0004 * lat ** 3
        band_width = 140
        peak_cat = 4.4
    d = lon - center_lon
    if d < -180:
        d += 360
    if d > 180:
        d -= 360
    x = d / band_width
    if abs(x) > 1.4:
        return 0
    falloff = math.exp(-x * x * 2.2)
    cat_f = peak_cat * falloff
    if cat_f >= 3.6:  return 4
    if cat_f >= 2.0:  return 3
    if cat_f >= 1.0:  return 2
    if cat_f >= 0.35: return 1
    return 0


def build_grid():
    """Returns 90×180 numpy array of category 0..4 for evening 29."""
    grid = np.zeros((90, 180), dtype=np.int8)
    for li in range(90):
        lat = -89 + li * 2
        for loi in range(180):
            lon = -179 + loi * 2
            grid[li, loi] = cat_at(lon, lat, evening=29)
    return grid


def add_grid_cells(ax, grid, projection_for_data, alpha_scale=1.0):
    """Plot 2°×2° cells as patches."""
    patches = []
    colors = []
    for li in range(90):
        lat = -89 + li * 2
        for loi in range(180):
            cat = grid[li, loi]
            if cat == 0:
                continue
            lon = -179 + loi * 2
            patches.append(
                mpatches.Rectangle((lon - 1, lat - 1), 2, 2)
            )
            base = list(CAT_COLORS[cat])
            base[3] *= alpha_scale
            colors.append(tuple(base))
    coll = PatchCollection(patches, facecolors=colors, edgecolors="none",
                           transform=ccrs.PlateCarree())
    ax.add_collection(coll)


def add_legend(ax, light=False):
    text_color = "#384a5e" if light else "#cdd8e3"
    handles = [
        mpatches.Patch(facecolor=color, edgecolor="none", label=label)
        for label, color in LEGEND_LABELS
    ]
    leg = ax.legend(
        handles=handles, loc="lower center", bbox_to_anchor=(0.5, -0.18),
        ncol=4, frameon=False, fontsize=9,
        labelcolor=text_color,
        handlelength=1.4, handleheight=1.0, columnspacing=1.6,
    )


# ───────────────────────────────────────────────
# OPTION 2 — Equirectangular Canvas + outline overlay
# ───────────────────────────────────────────────
def render_option_2():
    fig = plt.figure(figsize=(10, 5.6), dpi=110, facecolor="#05101e")
    ax = plt.axes(projection=ccrs.PlateCarree())
    ax.set_global()
    ax.set_facecolor("#05101e")

    grid = build_grid()
    add_grid_cells(ax, grid, ccrs.PlateCarree())

    # Country outlines (this is what the bundled PNG would look like)
    ax.add_feature(cfeature.COASTLINE.with_scale("110m"),
                   edgecolor=(180/255, 210/255, 245/255, 0.55), linewidth=0.6)
    ax.add_feature(cfeature.BORDERS.with_scale("110m"),
                   edgecolor=(180/255, 210/255, 245/255, 0.22), linewidth=0.3)

    # Graticule
    gl = ax.gridlines(crs=ccrs.PlateCarree(), color=(1, 1, 1, 0.06), linewidth=0.4,
                      xlocs=range(-180, 181, 30), ylocs=range(-90, 91, 30))

    # Equator gold tint
    ax.plot([-180, 180], [0, 0], color=(201/255, 162/255, 39/255, 0.45),
            linewidth=0.8, transform=ccrs.PlateCarree())

    # User location (Brampton)
    ax.scatter([-79.7], [43.7], s=140, facecolors="none",
               edgecolors=(201/255, 162/255, 39/255, 0.6), linewidths=1.5,
               transform=ccrs.PlateCarree())
    ax.scatter([-79.7], [43.7], s=40, facecolors="white",
               edgecolors=(201/255, 162/255, 39/255, 1.0), linewidths=1.5,
               transform=ccrs.PlateCarree())

    ax.set_title(
        "Option 2 · SwiftUI Canvas + bundled outline PNG · equirectangular",
        color=(232/255, 216/255, 160/255), fontsize=12, fontweight="bold",
        pad=10, loc="left",
    )

    add_legend(ax, light=False)

    fig.text(0.5, 0.04,
             "Render: dark fill → grid cells → bundled country outline PNG → user dot.   "
             "~10 ms.   No external deps.",
             ha="center", color=(140/255, 155/255, 170/255), fontsize=8.5)
    fig.text(0.5, 0.015,
             "Cells use the same equirectangular projection as moonsighting.com — visual parity guaranteed.",
             ha="center", color=(140/255, 155/255, 170/255), fontsize=8.5)

    plt.subplots_adjust(left=0.02, right=0.98, top=0.92, bottom=0.18)
    fig.savefig(
        os.path.join(OUT_DIR, "2026-05-10-hilal-map-option2-canvas-png.png"),
        facecolor="#05101e", bbox_inches="tight", pad_inches=0.15,
    )
    plt.close(fig)


# ───────────────────────────────────────────────
# OPTION 3 — MapKit muted-standard + Mercator overlays
# ───────────────────────────────────────────────
def render_option_3():
    fig = plt.figure(figsize=(10, 5.6), dpi=110, facecolor="#dde6ee")
    ax = plt.axes(projection=ccrs.Mercator(min_latitude=-75, max_latitude=75))
    ax.set_extent([-179.9, 179.9, -75, 75], crs=ccrs.PlateCarree())
    ax.set_facecolor("#cfdaeb")  # MapKit ocean

    # Land (MapKit muted-standard cream)
    ax.add_feature(cfeature.LAND.with_scale("110m"),
                   facecolor="#f0ebde", edgecolor=(150/255, 155/255, 165/255, 0.85),
                   linewidth=0.5, zorder=1)
    ax.add_feature(cfeature.BORDERS.with_scale("110m"),
                   edgecolor=(180/255, 185/255, 195/255, 0.7), linewidth=0.3, zorder=2)
    ax.add_feature(cfeature.LAKES.with_scale("110m"),
                   facecolor="#cfdaeb", zorder=2)

    # Visibility cells — overlaid semi-transparent
    grid = build_grid()
    add_grid_cells(ax, grid, ccrs.PlateCarree(), alpha_scale=0.75)

    # Ocean labels (MapKit-ish)
    label_color = (95/255, 110/255, 130/255, 0.75)
    label_kwargs = dict(color=label_color, fontsize=8, transform=ccrs.PlateCarree(),
                        ha="center", va="center", style="italic", zorder=4)
    ax.text(-150, 5, "PACIFIC OCEAN", **label_kwargs)
    ax.text(-30, 5, "ATLANTIC", **label_kwargs)
    ax.text(75, -25, "INDIAN OCEAN", **label_kwargs)

    # City labels
    city_kwargs = dict(color=(60/255, 75/255, 90/255), fontsize=7.5,
                       transform=ccrs.PlateCarree(), zorder=5)
    for name, lon, lat in [("Toronto", -79.4, 43.7),
                           ("London", -0.1, 51.5),
                           ("Mecca", 39.8, 21.4)]:
        ax.text(lon + 1.5, lat + 1, name, **city_kwargs)

    # User location pin (MapKit red)
    ax.scatter([-79.7], [43.7], s=80, color="#e02424",
               edgecolors="white", linewidths=1.5,
               transform=ccrs.PlateCarree(), zorder=6)

    # High-latitude distortion callout
    ax.annotate(
        "Mercator stretches cells\ndramatically at high latitudes",
        xy=(-100, 70), xytext=(-160, 73),
        xycoords=ccrs.PlateCarree()._as_mpl_transform(ax),
        textcoords=ccrs.PlateCarree()._as_mpl_transform(ax),
        color=(180/255, 50/255, 50/255), fontsize=8.5, fontweight="bold",
        arrowprops=dict(arrowstyle="->", color=(180/255, 50/255, 50/255), lw=1),
        zorder=7,
    )

    ax.set_title(
        "Option 3 · MapKit MKOverlay polygons · Mercator (note distortion)",
        color=(40/255, 60/255, 90/255), fontsize=12, fontweight="bold",
        pad=10, loc="left",
    )

    add_legend(ax, light=True)

    fig.text(0.5, 0.04,
             "Native pinch / zoom / pan.  Country borders + ocean labels for free.  "
             "Tap-to-inspect possible.",
             ha="center", color=(80/255, 95/255, 110/255), fontsize=8.5)
    fig.text(0.5, 0.015,
             "Trade-off: 16,200 polygon overlays + Mercator projection diverges from "
             "moonsighting.com at high latitudes.",
             ha="center", color=(150/255, 70/255, 70/255), fontsize=8.5)

    plt.subplots_adjust(left=0.02, right=0.98, top=0.92, bottom=0.18)
    fig.savefig(
        os.path.join(OUT_DIR, "2026-05-10-hilal-map-option3-mapkit.png"),
        facecolor="#dde6ee", bbox_inches="tight", pad_inches=0.15,
    )
    plt.close(fig)


if __name__ == "__main__":
    render_option_2()
    render_option_3()
    print("Wrote both PNGs.")
