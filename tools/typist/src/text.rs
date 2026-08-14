//! Font resolution, glyph caching and rasterized text blitting.
//!
//! Fonts are resolved once through fontconfig (`fc-match`), which hands back
//! both the file and the collection index, then memoized in
//! `$XDG_CACHE_HOME/typist` so later launches skip the subprocess entirely.
//!
//! Outlines are rasterized lazily and cached per (character, size). That matters
//! more than it sounds: a Nerd Font carries thousands of icon glyphs this app
//! will never draw, and a rasterizer that expands them all up front costs tens
//! of megabytes of resident memory for nothing.

use std::collections::HashMap;
use std::io::Write as _;
use std::path::PathBuf;
use std::process::Command;

use ab_glyph::{Font as _, FontRef, PxScale, ScaleFont as _};
use tiny_skia::{PixmapMut, PremultipliedColorU8};

use crate::theme::Rgba;

/// The four faces the UI draws with.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum Face {
    /// Monospace, for the prompt line.
    Mono,
    /// Proportional display weight, for the big result numerals.
    Display,
    /// Proportional semibold, for titles and the button label.
    Semibold,
    /// Proportional medium, for small labels.
    Medium,
}

/// The fontconfig patterns each face is matched against, most specific first.
const PATTERNS: [(Face, &str); 4] = [
    (Face::Mono, "JetBrainsMono Nerd Font Mono,JetBrains Mono,monospace:weight=regular"),
    (Face::Display, "Inter Display,Inter,sans-serif:weight=bold"),
    (Face::Semibold, "Inter,sans-serif:weight=semibold"),
    (Face::Medium, "Inter,sans-serif:weight=medium"),
];

struct Glyph {
    /// Coverage bitmap, one byte per pixel.
    cov: Vec<u8>,
    w: usize,
    h: usize,
    /// Offset from the pen position to the bitmap's left edge.
    left: f32,
    /// Offset from the baseline to the bitmap's top edge; negative is above.
    top: f32,
}

struct Loaded {
    font: FontRef<'static>,
    /// Converts an em-relative pixel size into ab_glyph's height-relative
    /// scale, so a "24px" request means the same thing across every face.
    scale_ratio: f32,
    /// `None` marks a character with no outline, such as a space, so it is not
    /// re-examined on every frame.
    glyphs: HashMap<(char, u32), Option<Glyph>>,
    advances: HashMap<(char, u32), f32>,
}

impl Loaded {
    fn scale(&self, px: f32) -> PxScale {
        PxScale::from(px * self.scale_ratio)
    }
}

pub struct Fonts {
    faces: HashMap<Face, Loaded>,
}

/// Quantize a pixel size to 1/8ths so the cache key is stable across float noise.
fn key_size(px: f32) -> u32 {
    (px * 8.0).round() as u32
}

impl Fonts {
    pub fn load() -> Result<Self, String> {
        let resolved = resolve_all()?;

        // Several faces usually live in one font collection, so read each file
        // at most once and let every face borrow the same bytes.
        let mut files: HashMap<PathBuf, &'static [u8]> = HashMap::new();
        let mut faces = HashMap::new();

        for (face, path, index) in resolved {
            let data = match files.get(&path) {
                Some(d) => *d,
                None => {
                    let bytes = std::fs::read(&path)
                        .map_err(|e| format!("reading font {}: {e}", path.display()))?;
                    // Deliberately leaked: the fonts are needed for the whole
                    // run, and this lets every face share one allocation
                    // without a self-referential struct.
                    let leaked: &'static [u8] = Box::leak(bytes.into_boxed_slice());
                    files.insert(path.clone(), leaked);
                    leaked
                }
            };

            let font = FontRef::try_from_slice_and_index(data, index).map_err(|e| {
                format!("parsing font {} (index {index}): {e}", path.display())
            })?;
            let upem = font.units_per_em().unwrap_or(1000.0);
            let scale_ratio = font.height_unscaled() / upem;

            faces.insert(face, Loaded {
                font,
                scale_ratio,
                glyphs: HashMap::new(),
                advances: HashMap::new(),
            });
        }

        Ok(Fonts { faces })
    }

    fn get(&mut self, face: Face) -> &mut Loaded {
        // Every variant is populated in `load`, which fails outright otherwise.
        self.faces.get_mut(&face).expect("face loaded")
    }

    /// Horizontal advance of a single character.
    pub fn advance(&mut self, face: Face, ch: char, px: f32) -> f32 {
        let k = (ch, key_size(px));
        let loaded = self.get(face);
        if let Some(a) = loaded.advances.get(&k) {
            return *a;
        }
        let scaled = loaded.font.as_scaled(loaded.scale(px));
        let a = scaled.h_advance(loaded.font.glyph_id(ch));
        loaded.advances.insert(k, a);
        a
    }

    /// Total advance width of a string.
    pub fn width(&mut self, face: Face, s: &str, px: f32) -> f32 {
        s.chars().map(|c| self.advance(face, c, px)).sum()
    }

    /// Cap height, measured from a real glyph so text can be optically centred
    /// on its capitals rather than on the em box.
    pub fn cap_height(&mut self, face: Face, px: f32) -> f32 {
        match self.glyph(face, 'H', px) {
            // `top` is the distance above the baseline, as a negative number.
            Some(g) => -g.top,
            None => px * 0.72,
        }
    }

    fn glyph(&mut self, face: Face, ch: char, px: f32) -> Option<&Glyph> {
        let k = (ch, key_size(px));
        let loaded = self.get(face);
        if !loaded.glyphs.contains_key(&k) {
            let scale = loaded.scale(px);
            let glyph = loaded.font.glyph_id(ch).with_scale(scale);
            let rendered = loaded.font.outline_glyph(glyph).map(|outlined| {
                let bounds = outlined.px_bounds();
                let w = (bounds.max.x - bounds.min.x).ceil().max(1.0) as usize;
                let h = (bounds.max.y - bounds.min.y).ceil().max(1.0) as usize;
                let mut cov = vec![0u8; w * h];
                outlined.draw(|x, y, c| {
                    let (x, y) = (x as usize, y as usize);
                    if x < w && y < h {
                        cov[y * w + x] = (c * 255.0 + 0.5).clamp(0.0, 255.0) as u8;
                    }
                });
                Glyph { cov, w, h, left: bounds.min.x, top: bounds.min.y }
            });
            loaded.glyphs.insert(k, rendered);
        }
        loaded.glyphs.get(&k).and_then(|g| g.as_ref())
    }

    /// Draw a single character with its left edge at the pen position and its
    /// baseline at `baseline`. Returns the advance to move the pen by.
    pub fn draw_char(
        &mut self,
        pm: &mut PixmapMut,
        face: Face,
        ch: char,
        pen: f32,
        baseline: f32,
        px: f32,
        color: Rgba,
    ) -> f32 {
        let adv = self.advance(face, ch, px);
        if color.a > 0.001 {
            if let Some(g) = self.glyph(face, ch, px) {
                let x0 = (pen + g.left).round() as i32;
                let y0 = (baseline + g.top).round() as i32;
                blit(pm, &g.cov, g.w, g.h, x0, y0, color);
            }
        }
        adv
    }

    /// Draw a string, returning the total advance.
    pub fn draw_str(
        &mut self,
        pm: &mut PixmapMut,
        face: Face,
        s: &str,
        pen: f32,
        baseline: f32,
        px: f32,
        color: Rgba,
    ) -> f32 {
        let mut x = pen;
        for ch in s.chars() {
            x += self.draw_char(pm, face, ch, x, baseline, px, color);
        }
        x - pen
    }

    /// Draw a string centred horizontally on `cx`.
    pub fn draw_centered(
        &mut self,
        pm: &mut PixmapMut,
        face: Face,
        s: &str,
        cx: f32,
        baseline: f32,
        px: f32,
        color: Rgba,
    ) {
        let w = self.width(face, s, px);
        self.draw_str(pm, face, s, cx - w / 2.0, baseline, px, color);
    }
}

/// Composite an 8-bit coverage bitmap onto the pixmap in premultiplied space.
fn blit(pm: &mut PixmapMut, cov: &[u8], w: usize, h: usize, x0: i32, y0: i32, color: Rgba) {
    let pw = pm.width() as i32;
    let ph = pm.height() as i32;
    // Clip to the pixmap before touching any pixels.
    let sx = (-x0).max(0);
    let sy = (-y0).max(0);
    let ex = (pw - x0).min(w as i32);
    let ey = (ph - y0).min(h as i32);
    if sx >= ex || sy >= ey {
        return;
    }

    // Channels are swapped to match the shm buffer's byte order; see
    // `Rgba::to_color` for why.
    let (cr, cg, cb) = (color.b as u32, color.g as u32, color.r as u32);
    let ca = (color.a.clamp(0.0, 1.0) * 255.0).round() as u32;
    if ca == 0 {
        return;
    }

    let pixels = pm.pixels_mut();
    for y in sy..ey {
        let row = &cov[(y as usize) * w..][..w];
        for x in sx..ex {
            let c = row[x as usize] as u32;
            if c == 0 {
                continue;
            }
            // Source alpha after tinting by the colour's own alpha.
            let a = (c * ca + 127) / 255;
            if a == 0 {
                continue;
            }
            let idx = ((y0 + y) as usize) * (pw as usize) + (x0 + x) as usize;
            let dst = pixels[idx];
            let inv = 255 - a;
            // Source is straight colour scaled by `a`; destination is premultiplied.
            let r = (cr * a + 127) / 255 + (dst.red() as u32 * inv + 127) / 255;
            let g = (cg * a + 127) / 255 + (dst.green() as u32 * inv + 127) / 255;
            let b = (cb * a + 127) / 255 + (dst.blue() as u32 * inv + 127) / 255;
            let na = (a + (dst.alpha() as u32 * inv + 127) / 255).min(255) as u8;
            pixels[idx] = PremultipliedColorU8::from_rgba(
                (r.min(255) as u8).min(na),
                (g.min(255) as u8).min(na),
                (b.min(255) as u8).min(na),
                na,
            )
            .unwrap_or(dst);
        }
    }
}

// ---------------------------------------------------------------------------
// Font resolution
// ---------------------------------------------------------------------------

fn cache_path() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))?;
    Some(base.join("typist").join("fonts"))
}

/// Resolve every face to a (file, collection index) pair, using the cache when
/// it is present and still points at files that exist.
fn resolve_all() -> Result<Vec<(Face, PathBuf, u32)>, String> {
    if let Some(hit) = read_cache() {
        return Ok(hit);
    }

    let mut out = Vec::with_capacity(PATTERNS.len());
    for (face, pattern) in PATTERNS {
        let (path, index) = fc_match(pattern)
            .ok_or_else(|| format!("fontconfig could not resolve a font for `{pattern}`"))?;
        out.push((face, path, index));
    }
    write_cache(&out);
    Ok(out)
}

fn read_cache() -> Option<Vec<(Face, PathBuf, u32)>> {
    let text = std::fs::read_to_string(cache_path()?).ok()?;
    let mut out = Vec::with_capacity(PATTERNS.len());
    for (line, (face, _)) in text.lines().zip(PATTERNS) {
        let (path, index) = line.rsplit_once('\t')?;
        let path = PathBuf::from(path);
        if !path.exists() {
            return None;
        }
        out.push((face, path, index.parse().ok()?));
    }
    (out.len() == PATTERNS.len()).then_some(out)
}

fn write_cache(entries: &[(Face, PathBuf, u32)]) {
    let Some(path) = cache_path() else { return };
    let Some(dir) = path.parent() else { return };
    if std::fs::create_dir_all(dir).is_err() {
        return;
    }
    let mut buf = String::new();
    for (_, p, i) in entries {
        buf.push_str(&format!("{}\t{}\n", p.display(), i));
    }
    if let Ok(mut f) = std::fs::File::create(&path) {
        let _ = f.write_all(buf.as_bytes());
    }
}

fn fc_match(pattern: &str) -> Option<(PathBuf, u32)> {
    let out = Command::new("fc-match")
        .arg("-f")
        .arg("%{file}\t%{index}")
        .arg(pattern)
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let s = String::from_utf8(out.stdout).ok()?;
    let (file, index) = s.trim().rsplit_once('\t')?;
    if file.is_empty() {
        return None;
    }
    Some((PathBuf::from(file), index.trim().parse().unwrap_or(0)))
}
