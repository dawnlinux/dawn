//! Colours and the handful of proportions the layout is derived from.

use tiny_skia::Color;

#[derive(Clone, Copy)]
pub struct Rgba {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: f32,
}

impl Rgba {
    pub const fn new(r: u8, g: u8, b: u8, a: f32) -> Self {
        Rgba { r, g, b, a }
    }

    /// Same colour at a different opacity.
    pub const fn alpha(self, a: f32) -> Self {
        Rgba { a, ..self }
    }

    /// Scale the existing opacity, used for edge fades and fade-in.
    pub fn fade(self, k: f32) -> Self {
        Rgba { a: self.a * k, ..self }
    }

    /// Convert for drawing into a `wl_shm` ARGB8888 buffer.
    ///
    /// That format is a little-endian 32-bit word, so its bytes run B, G, R, A,
    /// whereas tiny-skia writes R, G, B, A. Swapping the two channels here — and
    /// in the one other place colours reach memory, `text::blit` — means the
    /// whole surface can be rendered in place with no post-pass to fix it up.
    pub fn to_color(self) -> Color {
        Color::from_rgba8(self.b, self.g, self.r, (self.a.clamp(0.0, 1.0) * 255.0).round() as u8)
    }
}

/// Panel backdrop. Deliberately translucent so the compositor's blur is what
/// gives the window its depth; the tint only guarantees legible contrast.
pub const SCRIM: Rgba = Rgba::new(18, 16, 20, 0.55);
/// Hairline inset border along the panel edge.
pub const EDGE: Rgba = Rgba::new(255, 255, 255, 0.10);

/// Characters already typed correctly.
pub const TYPED: Rgba = Rgba::new(233, 226, 223, 1.0);
/// Characters not yet reached. Kept bright enough to stay readable when the
/// blur behind the panel happens to be very dark.
pub const PENDING: Rgba = Rgba::new(162, 155, 159, 0.72);
/// Characters typed wrongly.
pub const ERROR: Rgba = Rgba::new(224, 105, 116, 1.0);
/// Wrong character that happens to be a space, drawn as a filled slab.
pub const ERROR_SPACE: Rgba = Rgba::new(224, 105, 116, 0.30);
/// The caret.
pub const CARET: Rgba = Rgba::new(232, 185, 224, 1.0);

/// Small text: the word counter and the results title.
pub const HEADING: Rgba = Rgba::new(214, 207, 210, 0.85);
/// Big result numerals.
pub const NUMERAL: Rgba = Rgba::new(240, 234, 231, 1.0);
/// Labels beneath the numerals and the meta row.
pub const LABEL: Rgba = Rgba::new(160, 154, 156, 0.9);
/// Divider between the two result figures.
pub const DIVIDER: Rgba = Rgba::new(255, 255, 255, 0.14);

/// Pill button fill and its text.
pub const ACCENT: Rgba = Rgba::new(232, 185, 224, 1.0);
pub const ACCENT_HOVER: Rgba = Rgba::new(241, 201, 233, 1.0);
pub const ON_ACCENT: Rgba = Rgba::new(42, 31, 43, 1.0);

/// Corner radius of the panel, in logical pixels. Mirror this in the Hyprland
/// `rounding` rule so the compositor clips exactly where the scrim ends.
pub const RADIUS: f32 = 16.0;

// Every size below is a fraction of the window's height, so the layout holds
// its proportions at any window size and on any display scale. The values are
// measured off the reference screenshots.

/// Prompt text size.
pub const PROMPT_RATIO: f32 = 0.035;
/// Result numeral size.
pub const NUMERAL_RATIO: f32 = 0.073;
/// Small text: counter, title, labels, meta row, button.
pub const SMALL_RATIO: f32 = 0.020;

/// The content block sits slightly above true centre, which reads as centred.
pub const OPTICAL_CENTRE: f32 = 0.45;
/// Horizontal offset of each result figure from the divider.
pub const FIGURE_OFFSET: f32 = 0.142;
/// Inset of the title baseline and the close button from the top.
pub const TOP_INSET: f32 = 0.045;
/// Inset of the close button from the right edge.
pub const CORNER_INSET: f32 = 0.028;

/// The height the ratios above are applied to.
///
/// The reference proportions assume a landscape panel. Keying sizes off raw
/// height alone would make a tall, narrow window render enormous text, so the
/// height is capped against the width. At the intended aspect this is simply
/// the height and changes nothing.
pub fn metric(w: f32, h: f32) -> f32 {
    h.min(w * 0.62)
}

pub fn prompt_px(m: f32) -> f32 {
    (m * PROMPT_RATIO).clamp(15.0, 48.0)
}

pub fn numeral_px(m: f32) -> f32 {
    (m * NUMERAL_RATIO).clamp(34.0, 130.0)
}

pub fn small_px(m: f32) -> f32 {
    (m * SMALL_RATIO).clamp(11.0, 26.0)
}
