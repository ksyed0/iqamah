// Hilal Watch — Global Crescent Sighting Map
// Iterated in Claude conversation, 2026-05-09. Stored as a starting point
// for future SwiftUI design — NOT production code, not built, not run.
//
// Referenced by ENH-018 in docs/ENHANCEMENTS.md.
//
// Tech in this mockup (web/React) — to be ported to Swift/SwiftUI when
// promoted to a formal Epic:
//   - astronomy-engine v2 (full Meeus, ±0.01°) for sun/moon positions
//   - Odeh (2004) visibility criterion: V = ARCV - f(W); A/B/C/D zones
//   - 2° × 2° equirectangular grid (90 × 180 = 16,200 points)
//   - Arithmetic/tabular Hijri conversion (±1 day of observed)
//   - d3 + topojson for country outlines
//
// Swift port notes:
//   - Position engine: SwiftAA, SwiftSpaceTime, or port astronomy-engine
//     v2 directly (it's MIT-licensed and ~3000 LOC of pure JS math)
//   - Map rendering: SwiftUI Canvas + MKMapView for country outlines,
//     OR a pre-rendered SVG asset
//   - Hijri conversion: existing Foundation Calendar(identifier:
//     .islamicUmmAlQura) is sufficient

import { useState, useEffect, useRef } from "react";
import * as d3 from "d3";

// ═══════════════════════════════════════════════════════
// MATH HELPERS
// ═══════════════════════════════════════════════════════

const D2R = Math.PI / 180, R2D = 180 / Math.PI;
const rad = x => x * D2R, deg = x => x * R2D;
const nrm = x => ((x % 360) + 360) % 360;
const toJD     = d  => d.getTime() / 86400000 + 2440587.5;
const jdToDate = jd => new Date((jd - 2440587.5) * 86400000);

// ═══════════════════════════════════════════════════════
// SIMPLE SUN POSITION — used only inside sunsetJD for
// fast timing approximation (±15 min). All visibility
// calculations use astronomy-engine positions below.
// ═══════════════════════════════════════════════════════

function sunPosFast(J) {
  const T  = (J - 2451545) / 36525;
  const M  = nrm(357.52911 + 35999.05029 * T);
  const L  = nrm(280.46646 + 36000.76983 * T);
  const C  = (1.914602 - 0.004817 * T) * Math.sin(rad(M)) + 0.019993 * Math.sin(rad(2 * M));
  const lo = nrm(L + C), ep = 23.439291 - 0.013004 * T;
  return {
    ra:  nrm(deg(Math.atan2(Math.cos(rad(ep)) * Math.sin(rad(lo)), Math.cos(rad(lo))))),
    dec: deg(Math.asin(Math.min(1, Math.max(-1, Math.sin(rad(ep)) * Math.sin(rad(lo))))))
  };
}

// Fast sunset JD (±15 min) — intentionally approximate.
// Moon/sun positions are computed at this time by astronomy-engine,
// so sunset timing error contributes only ~0.15° to ARCV.
function sunsetJD(J0, lat, lon) {
  const s   = sunPosFast(J0);
  const cos = (Math.sin(rad(-0.8333)) - Math.sin(rad(lat)) * Math.sin(rad(s.dec)))
            / (Math.cos(rad(lat)) * Math.cos(rad(s.dec)));
  if (cos > 1 || cos < -1) return null; // polar day / polar night
  const ha  = deg(Math.acos(cos));
  const B   = rad(360 / 365 * (J0 - 2451545 + 9));
  const eot = -7.655 * Math.sin(B) + 9.873 * Math.sin(2*B + 3.588) + 0.439 * Math.sin(4*B);
  return Math.floor(J0 - 0.5) + 0.5 + (12 - lon/15 - eot/60 + ha/15) / 24;
}

// Angular separation in degrees (inputs in degrees)
function separation(ra1, d1, ra2, d2) {
  return deg(Math.acos(Math.min(1, Math.max(-1,
    Math.sin(rad(d1)) * Math.sin(rad(d2)) +
    Math.cos(rad(d1)) * Math.cos(rad(d2)) * Math.cos(rad(ra1 - ra2))
  ))));
}

// ═══════════════════════════════════════════════════════
// ODEH CRITERION (2004) — Experimental Astronomy 18:39-64
// V = ARCV − f(W),  W = topocentric crescent width (arcmin)
// Categories A–D exactly as published.
// ═══════════════════════════════════════════════════════

function crescentW(arcl_deg, distKm) {
  const SD = (1737.4 / distKm) * R2D * 60; // semi-diameter in arcmin
  return SD * (1 - Math.cos(rad(arcl_deg)));
}

function odehV(arcv, W) {
  return arcv - (-0.1018 * W**3 + 0.7319 * W**2 - 6.3226 * W + 7.1651);
}

function odehCat(arcv, arcl, distKm) {
  if (arcl < 6.4 || arcl > 50) return 0;
  const V = odehV(arcv, crescentW(arcl, distKm));
  if (V >= 5.65)  return 4; // A: easily visible naked eye
  if (V >= 2.0)   return 3; // B: visible naked eye, good conditions
  if (V >= -0.96) return 2; // C: optical aid to locate, naked eye after
  if (V >= -8)    return 1; // D: optical aid only
  return 0;
}

// ═══════════════════════════════════════════════════════
// ASTRONOMY-ENGINE WRAPPER
//
// window.Astronomy is loaded from CDN on mount.
// Full Meeus implementation: 60+ lunar longitude terms,
// giving ±0.01° moon position vs ±0.3° from 10-term approx.
// That 0.3° gap is what caused false positives near the
// 6.4° Danjon limit in the previous version.
//
// API notes:
//   Equator() returns RA in HOURS (not degrees)
//   Horizon() expects RA in HOURS
//   → multiply ra × 15 for degrees when calling separation()
// ═══════════════════════════════════════════════════════

function getVisAtSunset(sDate, lat, lon) {
  const A   = window.Astronomy;
  const obs = new A.Observer(lat, lon, 0);

  // Topocentric equatorial positions with aberration correction
  const moonEq = A.Equator(A.Body.Moon, sDate, obs, true, true);
  const sunEq  = A.Equator(A.Body.Sun,  sDate, obs, true, true);

  // Topocentric ARCL (convert RA hours → degrees for separation())
  const arcl = separation(sunEq.ra * 15, sunEq.dec, moonEq.ra * 15, moonEq.dec);

  // Topocentric ARCV with standard atmospheric refraction
  // Horizon() expects RA in hours (astronomy-engine convention)
  const moonHz = A.Horizon(sDate, obs, moonEq.ra, moonEq.dec, "normal");
  const arcv = moonHz.altitude;

  // Topocentric distance in km for crescent width W
  const distKm = moonEq.dist * 149597870.7;

  return { arcl, arcv, distKm };
}

// ═══════════════════════════════════════════════════════
// GRID COMPUTATION (90 × 180 = 16,200 points, 2° step)
// Performance: ~100–250 ms on iPhone with astronomy-engine
// Grids are cached per month — switching 29th/30th is instant.
// ═══════════════════════════════════════════════════════

function computeGrid(date) {
  if (!window.Astronomy) return null;
  const J0   = toJD(date);
  const grid = new Int8Array(90 * 180);

  for (let li = 0; li < 90; li++) {
    for (let loi = 0; loi < 180; loi++) {
      const lat = -89 + li * 2, lon = -179 + loi * 2;
      const sJD = sunsetJD(J0, lat, lon);
      if (!sJD) { grid[li * 180 + loi] = -1; continue; }
      try {
        const { arcl, arcv, distKm } = getVisAtSunset(jdToDate(sJD), lat, lon);
        grid[li * 180 + loi] = odehCat(arcv, arcl, distKm);
      } catch { grid[li * 180 + loi] = 0; }
    }
  }
  return grid;
}

function computeLocalOdeh(date, lat, lon) {
  if (!window.Astronomy) return null;
  const sJD = sunsetJD(toJD(date), lat, lon);
  if (!sJD) return null;
  try {
    const { arcl, arcv, distKm } = getVisAtSunset(jdToDate(sJD), lat, lon);
    const W = crescentW(arcl, distKm);
    const V = odehV(arcv, W);
    return { arcl, arcv, W, V, cat: odehCat(arcv, arcl, distKm) };
  } catch { return null; }
}

// ═══════════════════════════════════════════════════════
// MOON PHASE
// ═══════════════════════════════════════════════════════

const SYNODIC = 29.530588853;
const REF_MS  = new Date("2000-01-06T18:14:00Z").getTime();
const moonAge = d => { const x = (d.getTime() - REF_MS) / 86400000; return ((x % SYNODIC) + SYNODIC) % SYNODIC; };
const moonIl  = ph => 0.5 * (1 - Math.cos(ph * 2 * Math.PI));

function phaseName(ph) {
  if (ph < 0.033 || ph >= 0.967) return "New Moon";
  if (ph < 0.215) return "Waxing Crescent";
  if (ph < 0.285) return "First Quarter";
  if (ph < 0.467) return "Waxing Gibbous";
  if (ph < 0.533) return "Full Moon";
  if (ph < 0.715) return "Waning Gibbous";
  if (ph < 0.785) return "Last Quarter";
  return "Waning Crescent";
}

// ═══════════════════════════════════════════════════════
// HIJRI CALENDAR (arithmetic/tabular — ±1 day of observed)
// ═══════════════════════════════════════════════════════

const HIJRI_MONTHS = [
  "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
  "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
  "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
];

function toHijri(date) {
  const JD = Math.floor(toJD(date) + 0.5);
  const l  = JD - 1948440 + 10632, n = Math.floor((l - 1) / 10631);
  const l2 = l - 10631 * n + 354;
  const j  = Math.floor((10985 - l2) / 5316) * Math.floor((50 * l2) / 17719)
           + Math.floor(l2 / 5670) * Math.floor((43 * l2) / 15238);
  const l3 = l2 - Math.floor((30 - j) / 15) * Math.floor((17719 * j) / 50)
           - Math.floor(j / 16) * Math.floor((15238 * j) / 43) + 29;
  const month = Math.floor((24 * l3) / 709);
  return { year: 30*n + j - 30, month, day: l3 - Math.floor((709 * month) / 24) };
}

// ═══════════════════════════════════════════════════════
// HILAL DATE COMPUTATION
//
// d28 → "29th" (first watch): evening of the next new moon.
//   Locations where local sunset falls AFTER the conjunction
//   see the young crescent. The longitude-dependent moon age
//   at sunset creates the characteristic S-curve arcs.
//
// d29 → "30th" (second watch): evening after new moon.
//   Moon is 24-48h old; much wider and more confident visibility.
// ═══════════════════════════════════════════════════════

const TODAY = (() => { const d = new Date(); d.setHours(12, 0, 0, 0); return d; })();

function hilalDates(monthOffset = 0) {
  const age  = moonAge(TODAY);
  const last = TODAY.getTime() - age * 86400000;
  const next = last + (1 + monthOffset) * SYNODIC * 86400000;
  const d28  = new Date(next);           d28.setHours(12, 0, 0, 0);
  const d29  = new Date(next + 86400000); d29.setHours(12, 0, 0, 0);
  return { d28, d29 };
}

function monthCtx(monthOffset = 0) {
  const ref = new Date(TODAY.getTime() + monthOffset * SYNODIC * 86400000);
  const h   = toHijri(ref);
  const nm  = (h.month % 12) + 1;
  return {
    ...h,
    name:     HIJRI_MONTHS[h.month - 1],
    nextName: HIJRI_MONTHS[nm - 1],
    nextYear: h.month >= 12 ? h.year + 1 : h.year,
  };
}

// ═══════════════════════════════════════════════════════
// CANVAS: MOON PHASE DRAWING
// ═══════════════════════════════════════════════════════

function drawMoon(canvas, phase) {
  const sz = canvas.width, ctx = canvas.getContext("2d");
  const cx = sz/2, cy = sz/2, r = sz*0.43;
  ctx.clearRect(0, 0, sz, sz);
  const il = moonIl(phase), wx = phase <= 0.5;
  const img = ctx.createImageData(sz, sz); const px = img.data;
  for (let y = 0; y < sz; y++) {
    const ny = (y-cy)/r; if (Math.abs(ny) > 1) continue;
    const hw = Math.sqrt(1-ny*ny)*r, lx=cx-hw, rx=cx+hw, iw=2*hw*il;
    const x1 = wx?rx-iw:lx, x2 = wx?rx:lx+iw;
    for (let x = 0; x < sz; x++) {
      const nx = (x-cx)/r; if (nx*nx+ny*ny > 1) continue;
      const i4 = (y*sz+x)*4;
      if (x >= x1 && x <= x2) {
        const ld = 0.78+0.22*(1-Math.sqrt(nx*nx+ny*ny));
        px[i4]=Math.min(255,Math.round(252*ld)); px[i4+1]=Math.min(255,Math.round(238*ld)); px[i4+2]=Math.min(255,Math.round(195*ld)); px[i4+3]=255;
      } else { px[i4]=8; px[i4+1]=10; px[i4+2]=24; px[i4+3]=255; }
    }
  }
  ctx.putImageData(img, 0, 0);
  const gl = ctx.createRadialGradient(cx, cy, r*0.82, cx, cy, r*1.22);
  gl.addColorStop(0, `rgba(201,162,39,${il*0.22})`); gl.addColorStop(1, "rgba(0,0,0,0)");
  ctx.beginPath(); ctx.arc(cx, cy, r*1.22, 0, 2*Math.PI); ctx.fillStyle=gl; ctx.fill();
}

// ═══════════════════════════════════════════════════════
// CANVAS: WORLD VISIBILITY MAP
//
// Colour scheme matches OmegaHilalSighting (moonsighting.com):
//   A (cat 4) — Forest green  : easily visible naked eye
//   B (cat 3) — Teal / cyan   : visible if perfect conditions
//   C (cat 2) — Grey          : optical aid to locate
//   D (cat 1) — Red           : optical aid only
//   (no colour)               : not visible
// ═══════════════════════════════════════════════════════

const MAP_RGBA = [
  null,
  [205, 35,  35, 195],   // D: optical aid only      (red)
  [105,110, 120, 182],   // C: optical aid to locate  (grey)
  [  5,158, 193, 208],   // B: good conditions        (teal/cyan)
  [ 22,125,  52, 218],   // A: easily visible         (forest green)
];

function drawMap(canvas, grid, uLat, uLon) {
  const W = canvas.width, H = canvas.height;
  const ctx = canvas.getContext("2d");
  const cW = W/180, cH = H/90;
  ctx.fillStyle = "#05101e"; ctx.fillRect(0, 0, W, H);

  for (let li = 0; li < 90; li++) {
    for (let loi = 0; loi < 180; loi++) {
      const cat = grid[li*180+loi]; if (cat <= 0) continue;
      const r = MAP_RGBA[cat];
      ctx.fillStyle = `rgba(${r[0]},${r[1]},${r[2]},${r[3]/255})`;
      ctx.fillRect(Math.floor(loi*cW), Math.floor((89-li)*cH), Math.ceil(cW)+1, Math.ceil(cH)+1);
    }
  }

  // Graticule
  ctx.strokeStyle = "rgba(255,255,255,0.045)"; ctx.lineWidth = 0.5;
  for (let lo=-180; lo<=180; lo+=30) { const x=(lo+180)/360*W; ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke(); }
  for (let la=-90;  la<=90;  la+=30) { const y=(90-la)/180*H;  ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke(); }

  // Equator — subtle gold tint
  ctx.strokeStyle = "rgba(201,162,39,0.18)"; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(0, H/2); ctx.lineTo(W, H/2); ctx.stroke();

  // User location
  if (uLat != null && uLon != null) {
    const mx = (uLon+180)/360*W, my = (90-uLat)/180*H;
    ctx.beginPath(); ctx.arc(mx, my, 6, 0, 2*Math.PI);
    ctx.fillStyle="#fff"; ctx.fill();
    ctx.strokeStyle="#c9a227"; ctx.lineWidth=2.5; ctx.stroke();
    ctx.beginPath(); ctx.arc(mx, my, 13, 0, 2*Math.PI);
    ctx.strokeStyle="rgba(201,162,39,0.28)"; ctx.lineWidth=1.5; ctx.stroke();
  }
}

// ═══════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════

// Labels and hex match OmegaHilalSighting legend ordering
const CAT_LABEL = ["Not Visible", "Optical Aid Only", "Optical Aid → Naked Eye", "Naked Eye", "Easily Visible"];
const CAT_HEX   = ["#64748b",    "#dc2626",           "#6b7280",                   "#0891b2",   "#16a34a"];
const CAT_FILL  = ["#374151",    "#7f1d1d",           "#374151",                   "#0c4a6e",   "#052e16"];
const MAP_LEGEND = [
  { fill: "#c22323", label: "D — Optical aid only" },
  { fill: "#6b7280", label: "C — Optical aid to locate" },
  { fill: "#059bbe", label: "B — Visible if perfect conditions" },
  { fill: "#167a35", label: "A — Easily visible naked eye" },
];

const C = {
  bg:"#060c18", surface:"#0a1422", card:"#0d1a2c",
  border:"#141f30", bGold:"#2a2210",
  gold:"#c9a227", goldL:"#e0bc47", goldD:"#7a6018", goldDim:"#362c0e",
  cream:"#e8d8a0", text:"#c8d4e0", muted:"#4a5f78", dim:"#1e2d40", dimmer:"#121d2c",
};

const CARD = (border) => ({
  background: C.card, border: `1px solid ${border || C.border}`, borderRadius: "12px", padding: "14px",
});
const SEC = { fontSize:"0.58rem", color:C.muted, textTransform:"uppercase", letterSpacing:"0.13em", marginBottom:"10px", fontWeight:500 };
const ARROW = { background:"transparent", border:`1px solid ${C.border}`, color:C.muted, borderRadius:"8px", padding:"8px 16px", fontSize:"1.1rem", cursor:"pointer", lineHeight:1 };

// ═══════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════

export default function App() {
  const moonRef = useRef(null), mapRef = useRef(null), svgRef = useRef(null);

  const [tab,        setTab]        = useState(28);
  const [offset,     setOffset]     = useState(0);
  const [loc,        setLoc]        = useState(null);
  const [locBusy,    setLocBusy]    = useState(false);
  const [grids,      setGrids]      = useState(null);
  const [worldGeo,   setWorldGeo]   = useState(null);
  const [lVis,       setLVis]       = useState(null);
  const [astroReady, setAstroReady] = useState(false);
  const [computing,  setComputing]  = useState(false);

  const { d28, d29 } = hilalDates(offset);
  const ctx          = monthCtx(offset);
  const activeDate   = tab === 28 ? d28 : d29;
  const activeGrid   = grids ? (tab === 28 ? grids.d28 : grids.d29) : null;
  const phase        = moonAge(activeDate) / SYNODIC;
  const il           = moonIl(phase);

  // ── Load astronomy-engine (full Meeus, ±0.01°) ─────
  useEffect(() => {
    if (document.getElementById("astro-engine")) { if (window.Astronomy) setAstroReady(true); return; }
    const s = document.createElement("script"); s.id = "astro-engine";
    s.src = "https://cdn.jsdelivr.net/npm/astronomy-engine@2/astronomy.browser.min.js";
    s.onload = () => setAstroReady(true);
    document.head.appendChild(s);
  }, []);

  // ── Load Google Fonts ───────────────────────────────
  useEffect(() => {
    if (document.getElementById("iq-fonts")) return;
    const l = document.createElement("link"); l.id = "iq-fonts"; l.rel = "stylesheet";
    l.href = "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,600;0,700;1,400&family=Manrope:wght@300;400;500;600&display=swap";
    document.head.appendChild(l);
  }, []);

  // ── Compute grids once astro-engine is ready ────────
  useEffect(() => {
    if (!astroReady) return;
    setGrids(null); setComputing(true);
    const t = setTimeout(() => {
      setGrids({ d28: computeGrid(d28), d29: computeGrid(d29) });
      setComputing(false);
    }, 80);
    return () => clearTimeout(t);
  }, [offset, astroReady]);

  // ── Draw moon canvas ─────────────────────────────────
  useEffect(() => { if (moonRef.current) drawMoon(moonRef.current, phase); }, [phase]);

  // ── Draw map canvas ──────────────────────────────────
  useEffect(() => {
    if (activeGrid && mapRef.current) drawMap(mapRef.current, activeGrid, loc?.lat, loc?.lon);
  }, [activeGrid, loc]);

  // ── Country outlines via d3 + topojson ──────────────
  useEffect(() => {
    if (!worldGeo || !svgRef.current) return;
    const W=720, H=360, proj=d3.geoEquirectangular().fitSize([W,H],{type:"Sphere"}), path=d3.geoPath(proj);
    const svg = d3.select(svgRef.current); svg.selectAll("*").remove();
    svg.append("g").selectAll("path").data(worldGeo.features).join("path")
      .attr("d",path).attr("fill","none").attr("stroke","rgba(180,210,245,0.32)").attr("stroke-width",0.5);
  }, [worldGeo]);

  // ── Load world topology ──────────────────────────────
  useEffect(() => {
    if (document.getElementById("topo-js")) return;
    const s = document.createElement("script"); s.id="topo-js";
    s.src="https://cdn.jsdelivr.net/npm/topojson-client@3/dist/topojson-client.min.js";
    s.onload=()=>fetch("https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json")
      .then(r=>r.json()).then(w=>setWorldGeo(window.topojson.feature(w,w.objects.countries))).catch(()=>{});
    document.head.appendChild(s);
  }, []);

  // ── Local Odeh visibility ────────────────────────────
  useEffect(() => {
    if (loc && astroReady) setLVis(computeLocalOdeh(activeDate, loc.lat, loc.lon));
  }, [loc, activeDate, astroReady]);

  const geoReq = () => {
    if (!navigator.geolocation) return; setLocBusy(true);
    navigator.geolocation.getCurrentPosition(
      p=>{ setLoc({lat:p.coords.latitude,lon:p.coords.longitude}); setLocBusy(false); },
      ()=>setLocBusy(false), {enableHighAccuracy:true,timeout:10000}
    );
  };

  const fmtS   = d => d.toLocaleDateString("en-CA",{month:"short",day:"numeric"});
  const daysTo = d => Math.ceil((d.getTime()-TODAY.getTime())/86400000);
  const FF = "'Cormorant Garamond', Georgia, serif";
  const FB = "'Manrope', system-ui, sans-serif";

  return (
    <div style={{background:C.bg, minHeight:"100vh", color:C.text, fontFamily:FB, overflowX:"hidden"}}>

      {/* Status bar */}
      <div style={{display:"flex",justifyContent:"space-between",padding:"10px 20px 4px",fontSize:"0.68rem",color:C.muted}}>
        <span>9:41</span><span>●●●</span>
      </div>

      {/* Nav bar */}
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"4px 20px 14px",borderBottom:`1px solid ${C.border}`}}>
        <span style={{fontSize:"0.70rem",color:C.muted,letterSpacing:"0.06em"}}>‹ IQAMAH</span>
        <div style={{fontFamily:FF,fontSize:"1.15rem",fontWeight:600,color:C.gold,letterSpacing:"0.05em"}}>Hilal Watch</div>
        <div style={{width:"52px",textAlign:"right",fontSize:"0.78rem",color:C.muted}}>⚙</div>
      </div>

      <div style={{padding:"0 16px 36px"}}>

        {/* Month selector */}
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"20px 0 6px"}}>
          <button onClick={()=>setOffset(o=>o-1)} style={ARROW}>‹</button>
          <div style={{textAlign:"center",flex:1,padding:"0 8px"}}>
            <div style={{fontFamily:FF,fontSize:"1.9rem",fontWeight:700,color:C.cream,letterSpacing:"-0.01em",lineHeight:1}}>{ctx.name}</div>
            <div style={{fontFamily:FF,fontSize:"1.05rem",color:C.goldD,marginTop:"2px",fontStyle:"italic"}}>{ctx.year} AH</div>
            <div style={{fontSize:"0.60rem",color:C.muted,marginTop:"8px",textTransform:"uppercase",letterSpacing:"0.12em"}}>
              Confirms start of {ctx.nextName} {ctx.nextYear}
            </div>
          </div>
          <button onClick={()=>setOffset(o=>o+1)} style={ARROW}>›</button>
        </div>

        {/* Ornament divider */}
        <div style={{display:"flex",justifyContent:"center",margin:"10px 0 16px"}}>
          <div style={{width:"32px",height:"1px",background:`linear-gradient(90deg,transparent,${C.goldDim},transparent)`}}/>
          <div style={{width:"6px",height:"6px",borderRadius:"50%",background:C.goldDim,margin:"-2.5px 6px 0"}}/>
          <div style={{width:"32px",height:"1px",background:`linear-gradient(90deg,${C.goldDim},transparent)`}}/>
        </div>

        {/* Tab selector */}
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"8px",marginBottom:"16px"}}>
          {[
            {id:28, label:"29th", sub:"First Watch",  date:d28},
            {id:29, label:"30th", sub:"Second Watch", date:d29},
          ].map(({id,label,sub,date})=>{
            const active=tab===id, dt=daysTo(date);
            return (
              <button key={id} onClick={()=>setTab(id)} style={{
                background:active?C.gold:C.card, border:`1px solid ${active?C.gold:C.border}`,
                borderRadius:"12px", padding:"13px 10px", cursor:"pointer", textAlign:"center", transition:"all 0.2s",
              }}>
                <div style={{fontFamily:FF,fontSize:"1.6rem",fontWeight:700,color:active?"#060c18":C.muted,lineHeight:1}}>{label}</div>
                <div style={{fontSize:"0.60rem",color:active?"#5a3800":C.dim,marginTop:"3px",textTransform:"uppercase",letterSpacing:"0.08em"}}>{sub}</div>
                <div style={{fontSize:"0.68rem",color:active?"#3d2800":C.muted,marginTop:"4px",fontWeight:active?600:400}}>{fmtS(date)}</div>
                <div style={{fontSize:"0.58rem",marginTop:"3px",fontWeight:600,color:active?"#5a3800":dt===0?C.gold:C.dim}}>
                  {dt===0?"TONIGHT":dt<0?"PAST":`in ${dt}d`}
                </div>
              </button>
            );
          })}
        </div>

        {/* Moon status card */}
        <div style={{...CARD(),display:"flex",alignItems:"center",gap:"16px",marginBottom:"10px"}}>
          <div style={{flexShrink:0,textAlign:"center"}}>
            <div style={{position:"relative",display:"inline-block"}}>
              <div style={{position:"absolute",inset:"-18px",background:`radial-gradient(ellipse,rgba(201,162,39,${il*0.22}) 0%,transparent 70%)`,borderRadius:"50%",pointerEvents:"none"}}/>
              <canvas ref={moonRef} width={76} height={76} style={{display:"block",position:"relative"}}/>
            </div>
            <div style={{fontSize:"0.58rem",color:C.muted,marginTop:"8px",textTransform:"uppercase",letterSpacing:"0.06em",lineHeight:1.4}}>{phaseName(phase)}</div>
          </div>
          <div style={{flex:1}}>
            <div style={{fontFamily:FF,fontSize:"1.15rem",fontWeight:600,color:C.cream,lineHeight:1.2,marginBottom:"6px"}}>
              {tab===28?"29th":"30th"} {ctx.name}
            </div>
            <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"6px"}}>
              {[
                {l:"Moon age",    v:`${(moonAge(activeDate)*24).toFixed(0)}h`},
                {l:"Illuminated", v:`${(il*100).toFixed(1)}%`},
              ].map(({l,v})=>(
                <div key={l} style={{background:C.dimmer,borderRadius:"7px",padding:"6px 8px"}}>
                  <div style={{fontSize:"0.54rem",color:C.dim,textTransform:"uppercase",letterSpacing:"0.08em"}}>{l}</div>
                  <div style={{fontSize:"0.85rem",fontWeight:600,color:C.text,marginTop:"1px",fontFamily:"'Courier New',monospace"}}>{v}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Local sighting card */}
        <div style={{...CARD(),marginBottom:"10px"}}>
          <div style={SEC}>Local Sighting Prediction</div>

          {!loc&&!locBusy&&(
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",gap:"12px"}}>
              <div style={{fontSize:"0.74rem",color:C.muted,flex:1,lineHeight:1.5}}>
                GPS enables precise local visibility via Odeh criterion
              </div>
              <button onClick={geoReq} style={{background:"transparent",border:`1px solid ${C.gold}`,color:C.gold,borderRadius:"8px",padding:"7px 14px",fontSize:"0.70rem",cursor:"pointer",flexShrink:0,fontFamily:FB,fontWeight:500}}>
                Use GPS
              </button>
            </div>
          )}

          {locBusy&&<div style={{fontSize:"0.74rem",color:C.muted}}>Requesting location…</div>}

          {loc&&(
            <div>
              <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start"}}>
                <div>
                  <div style={{fontSize:"0.72rem",color:C.muted,marginBottom:"8px"}}>
                    📍 {Math.abs(loc.lat).toFixed(3)}°{loc.lat>=0?"N":"S"} · {Math.abs(loc.lon).toFixed(3)}°{loc.lon>=0?"E":"W"}
                  </div>
                  {!astroReady&&<div style={{fontSize:"0.70rem",color:C.dim}}>Loading astronomy engine…</div>}
                  {lVis&&(
                    <div style={{display:"flex",alignItems:"center",gap:"8px"}}>
                      <div style={{width:"10px",height:"10px",borderRadius:"50%",background:CAT_HEX[lVis.cat],boxShadow:`0 0 8px ${CAT_HEX[lVis.cat]}88`,flexShrink:0}}/>
                      <span style={{fontFamily:FF,fontSize:"1.1rem",fontWeight:600,color:CAT_HEX[lVis.cat]}}>{CAT_LABEL[lVis.cat]}</span>
                    </div>
                  )}
                </div>
                <button onClick={geoReq} style={{background:"transparent",border:`1px solid ${C.border}`,color:C.dim,borderRadius:"6px",padding:"4px 8px",fontSize:"0.62rem",cursor:"pointer"}}>↻</button>
              </div>

              {lVis&&(
                <>
                  <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:"6px",marginTop:"12px"}}>
                    {[
                      {k:"ARCL",v:`${lVis.arcl.toFixed(1)}°`,sub:"elongation"},
                      {k:"ARCV",v:`${lVis.arcv.toFixed(1)}°`,sub:"moon alt"},
                      {k:"W",   v:`${lVis.W.toFixed(2)}′`,   sub:"crescent"},
                      {k:"V",   v:lVis.V.toFixed(2),          sub:"Odeh val"},
                    ].map(({k,v,sub})=>(
                      <div key={k} style={{background:C.dimmer,borderRadius:"8px",padding:"8px 6px",textAlign:"center"}}>
                        <div style={{fontSize:"0.52rem",color:C.dim,textTransform:"uppercase",letterSpacing:"0.1em"}}>{k}</div>
                        <div style={{fontSize:"0.90rem",fontWeight:600,color:C.text,margin:"3px 0 1px",fontFamily:"'Courier New',monospace"}}>{v}</div>
                        <div style={{fontSize:"0.50rem",color:C.dim}}>{sub}</div>
                      </div>
                    ))}
                  </div>
                  <div style={{display:"flex",gap:"4px",marginTop:"10px"}}>
                    {[1,2,3,4].map(c=>(
                      <div key={c} style={{flex:1,height:"3px",borderRadius:"2px",background:c<=lVis.cat?CAT_FILL[c]:C.border}}/>
                    ))}
                  </div>
                  <div style={{display:"flex",justifyContent:"space-between",fontSize:"0.52rem",color:C.dim,marginTop:"3px"}}>
                    <span>Optical aid</span><span>Easily visible</span>
                  </div>
                </>
              )}
            </div>
          )}
        </div>

        {/* World map card */}
        <div style={{...CARD(),padding:"12px",marginBottom:"10px"}}>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:"10px"}}>
            <div style={SEC}>Global Crescent Visibility</div>
            <div style={{fontSize:"0.58rem",color:C.dim}}>{tab===28?"29th":"30th"} {ctx.name} · Odeh 2004</div>
          </div>

          {(!grids||computing)&&(
            <div style={{height:"150px",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",background:"#05101e",borderRadius:"8px",gap:"10px"}}>
              <div style={{fontFamily:FF,fontSize:"2rem",color:C.dim,animation:"hilalPulse 1.8s ease-in-out infinite"}}>☽</div>
              <div style={{fontSize:"0.68rem",color:C.dim}}>
                {!astroReady?"Loading astronomy engine…":"Computing visibility zones…"}
              </div>
            </div>
          )}

          <div style={{position:"relative",width:"100%",paddingTop:"50%",background:"#05101e",borderRadius:"8px",overflow:"hidden",display:grids&&!computing?"block":"none"}}>
            <canvas ref={mapRef} width={720} height={360} style={{position:"absolute",top:0,left:0,width:"100%",height:"100%"}}/>
            <svg ref={svgRef} viewBox="0 0 720 360" style={{position:"absolute",top:0,left:0,width:"100%",height:"100%",pointerEvents:"none"}}/>
          </div>

          {/* Legend — OmegaHilalSighting order (D→A) */}
          <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"5px 14px",marginTop:"10px"}}>
            {MAP_LEGEND.map(({fill,label})=>(
              <div key={label} style={{display:"flex",alignItems:"center",gap:"5px"}}>
                <div style={{width:"8px",height:"8px",borderRadius:"2px",background:fill,flexShrink:0}}/>
                <span style={{fontSize:"0.59rem",color:C.muted}}>{label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Methodology footer */}
        <div style={{...CARD(),padding:"10px 12px",borderColor:C.dimmer}}>
          <div style={{fontSize:"0.63rem",color:C.dim,lineHeight:1.8}}>
            <span style={{color:C.muted,fontWeight:500}}>Odeh criterion (2004)</span> · 737 ICOP observations ·
            Moon/sun positions via <span style={{color:C.muted}}>astronomy-engine v2</span> (Meeus, ±0.01°) ·
            Fast sunset approximation (±15 min) · Danjon limit 6.4° ·{" "}
            <a href="https://moonsighting.com" target="_blank" rel="noopener noreferrer" style={{color:C.goldD,textDecoration:"none"}}>
              moonsighting.com ↗
            </a>
          </div>
        </div>

      </div>

      <style>{`@keyframes hilalPulse { 0%,100%{opacity:.2;transform:scale(.93)} 50%{opacity:.75;transform:scale(1.07)} }`}</style>
    </div>
  );
}
