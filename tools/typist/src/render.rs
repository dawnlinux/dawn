//! Drawing. Everything works in device pixels and derives its sizes from the
//! window height, so display scale needs no special handling here.

use tiny_skia::{FillRule, Paint, PathBuilder, PixmapMut, Rect as SkRect, Shader, Transform};

use crate::state::{Mode, Phase, Test};
use crate::text::{Face, Fonts};
use crate::theme::{self, Rgba};

#[derive(Clone, Copy, Default)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl Rect {
    pub fn contains(&self, px: f32, py: f32) -> bool {
        px >= self.x && px < self.x + self.w && py >= self.y && py < self.y + self.h
    }
}

/// Presentation state that outlives a single frame: smoothed positions, the
/// caret blink, and the hit rectangles the pointer is tested against.
pub struct View {
    /// Smoothed left edge of the prompt line.
    pub scroll: f32,
    /// Smoothed caret position, in line space.
    pub caret: f32,
    /// Set once the first frame has established the initial positions.
    pub settled: bool,
    pub blink_on: bool,
    /// Results fade-in, 0 to 1.
    pub reveal: f32,
    pub hover_continue: bool,
    pub hover_close: bool,
    pub continue_rect: Rect,
    pub close_rect: Rect,
}

impl Default for View {
    fn default() -> Self {
        View {
            scroll: 0.0,
            caret: 0.0,
            settled: false,
            blink_on: true,
            reveal: 0.0,
            hover_continue: false,
            hover_close: false,
            continue_rect: Rect::default(),
            close_rect: Rect::default(),
        }
    }
}

impl View {
    /// Reset the smoothing so a new test snaps into place instead of sliding.
    pub fn reset_motion(&mut self) {
        self.settled = false;
        self.reveal = 0.0;
    }
}

/// Exponential smoothing that is stable regardless of frame timing.
fn approach(current: f32, target: f32, rate: f32, dt: f32) -> f32 {
    let k = 1.0 - (-rate * dt).exp();
    current + (target - current) * k
}

fn smoothstep(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

fn fill(pm: &mut PixmapMut, path: &tiny_skia::Path, color: Rgba) {
    let mut paint = Paint::default();
    paint.shader = Shader::SolidColor(color.to_color());
    paint.anti_alias = true;
    pm.fill_path(path, &paint, FillRule::Winding, Transform::identity(), None);
}

fn fill_rect(pm: &mut PixmapMut, x: f32, y: f32, w: f32, h: f32, color: Rgba) {
    if w <= 0.0 || h <= 0.0 {
        return;
    }
    let Some(r) = SkRect::from_xywh(x, y, w, h) else { return };
    let mut paint = Paint::default();
    paint.shader = Shader::SolidColor(color.to_color());
    paint.anti_alias = true;
    pm.fill_rect(r, &paint, Transform::identity(), None);
}

fn round_rect_path(x: f32, y: f32, w: f32, h: f32, r: f32) -> Option<tiny_skia::Path> {
    let r = r.min(w / 2.0).min(h / 2.0).max(0.0);
    // Circular-arc approximation constant for a cubic Bezier.
    let k = r * 0.552_284_75;
    let mut pb = PathBuilder::new();
    pb.move_to(x + r, y);
    pb.line_to(x + w - r, y);
    pb.cubic_to(x + w - r + k, y, x + w, y + r - k, x + w, y + r);
    pb.line_to(x + w, y + h - r);
    pb.cubic_to(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h);
    pb.line_to(x + r, y + h);
    pb.cubic_to(x + r - k, y + h, x, y + h - r + k, x, y + h - r);
    pb.line_to(x, y + r);
    pb.cubic_to(x, y + r - k, x + r - k, y, x + r, y);
    pb.close();
    pb.finish()
}

/// Draw a frame. `dt` is the time since the previous frame, in seconds.
pub fn draw(pm: &mut PixmapMut, fonts: &mut Fonts, test: &Test, view: &mut View, dt: f32, scale: f32) {
    let w = pm.width() as f32;
    let h = pm.height() as f32;
    pm.fill(tiny_skia::Color::TRANSPARENT);

    panel(pm, w, h, scale);

    match test.phase {
        Phase::Done => {
            view.reveal = approach(view.reveal, 1.0, 14.0, dt);
            results(pm, fonts, test, view, w, h, scale);
        }
        _ => {
            view.reveal = 0.0;
            view.continue_rect = Rect::default();
            view.close_rect = Rect::default();
            typing(pm, fonts, test, view, w, h, dt, scale);
        }
    }
}

/// The translucent backdrop and its hairline edge. The compositor's blur is
/// what fills this in; the tint only guarantees the text stays legible.
fn panel(pm: &mut PixmapMut, w: f32, h: f32, scale: f32) {
    let r = theme::RADIUS * scale;
    if let Some(p) = round_rect_path(0.0, 0.0, w, h, r) {
        fill(pm, &p, theme::SCRIM);
    }
    // A hairline inset by half its width so it lands fully inside the panel.
    let t = (scale).max(1.0);
    if let (Some(outer), Some(inner)) = (
        round_rect_path(t * 0.5, t * 0.5, w - t, h - t, r - t * 0.5),
        round_rect_path(t * 1.5, t * 1.5, w - t * 3.0, h - t * 3.0, r - t * 1.5),
    ) {
        // Even-odd between two outlines gives a crisp one-pixel ring.
        let mut pb = PathBuilder::new();
        pb.push_path(&outer);
        pb.push_path(&inner);
        if let Some(ring) = pb.finish() {
            let mut paint = Paint::default();
            paint.shader = Shader::SolidColor(theme::EDGE.to_color());
            paint.anti_alias = true;
            pm.fill_path(&ring, &paint, FillRule::EvenOdd, Transform::identity(), None);
        }
    }
}

fn typing(
    pm: &mut PixmapMut,
    fonts: &mut Fonts,
    test: &Test,
    view: &mut View,
    w: f32,
    h: f32,
    dt: f32,
    scale: f32,
) {
    // Sizes and insets scale with the aspect-corrected height; only vertical
    // placement uses the real height.
    let m = theme::metric(w, h);
    let px = theme::prompt_px(m);
    let small = theme::small_px(m);

    // The counter, or the countdown in timed mode.
    let header = match test.mode {
        Mode::Words(_) => format!("{}/{}", test.word_index(), test.words_total),
        Mode::Time(_) => format!("{}", test.remaining()),
    };
    fonts.draw_centered(
        pm,
        Face::Semibold,
        &header,
        w / 2.0,
        m * theme::TOP_INSET,
        small,
        theme::HEADING,
    );

    // Monospace, so one advance describes the whole line.
    let adv = fonts.advance(Face::Mono, 'm', px);
    let total = test.target.len() as f32 * adv;
    let pad = w * 0.06;
    let content = w - pad * 2.0;
    let cursor = test.cursor();

    // Centre a line that fits; otherwise scroll to hold the caret mid-window.
    let scroll_target = if total <= content {
        (w - total) / 2.0
    } else {
        (w / 2.0 - cursor as f32 * adv).clamp(w - pad - total, pad)
    };
    let caret_target = cursor as f32 * adv;

    if view.settled {
        view.scroll = approach(view.scroll, scroll_target, 18.0, dt);
        view.caret = approach(view.caret, caret_target, 34.0, dt);
    } else {
        view.scroll = scroll_target;
        view.caret = caret_target;
        view.settled = true;
    }

    let cap = fonts.cap_height(Face::Mono, px);
    let baseline = h * theme::OPTICAL_CENTRE + cap / 2.0;
    let overflowing = total > content;

    for (i, ch) in test.target.iter().enumerate() {
        let x = view.scroll + i as f32 * adv;
        if x + adv < 0.0 {
            continue;
        }
        if x > w {
            break;
        }

        // Fade characters as they approach either edge of a scrolling line.
        let k = if overflowing {
            let centre = x + adv * 0.5;
            smoothstep((centre / pad).min((w - centre) / pad))
        } else {
            1.0
        };
        if k <= 0.001 {
            continue;
        }

        if i < cursor {
            if test.correct_at(i) {
                fonts.draw_char(pm, Face::Mono, *ch, x, baseline, px, theme::TYPED.fade(k));
            } else if *ch == ' ' {
                // A wrong space would be invisible, so mark the gap itself.
                fill_rect(
                    pm,
                    x + adv * 0.1,
                    baseline - cap * 0.55,
                    adv * 0.8,
                    cap * 0.5,
                    theme::ERROR_SPACE.fade(k),
                );
            } else {
                fonts.draw_char(pm, Face::Mono, *ch, x, baseline, px, theme::ERROR.fade(k));
            }
        } else {
            fonts.draw_char(pm, Face::Mono, *ch, x, baseline, px, theme::PENDING.fade(k));
        }
    }

    // The caret.
    if view.blink_on {
        let cx = view.scroll + view.caret;
        let cw = (px * 0.06).max(1.5 * scale);
        let k = if overflowing {
            smoothstep((cx / pad).min((w - cx) / pad))
        } else {
            1.0
        };
        fill_rect(
            pm,
            cx - cw * 0.5,
            baseline - cap * 1.12,
            cw,
            cap * 1.34,
            theme::CARET.fade(k),
        );
    }

    // A quiet reminder of the two keys that matter, gone once you start.
    if test.phase == Phase::Idle {
        fonts.draw_centered(
            pm,
            Face::Medium,
            "tab restart   ·   esc quit",
            w / 2.0,
            h - m * theme::TOP_INSET * 0.7,
            small * 0.86,
            theme::LABEL.alpha(0.4),
        );
    }
}

fn results(
    pm: &mut PixmapMut,
    fonts: &mut Fonts,
    test: &Test,
    view: &mut View,
    w: f32,
    h: f32,
    scale: f32,
) {
    let a = smoothstep(view.reveal);
    // Sizes and insets scale with the aspect-corrected height; vertical
    // placement and the bottom anchor use the real height.
    let m = theme::metric(w, h);
    // Content settles downward into place as it fades in.
    let rise = (1.0 - a) * m * 0.012;

    let small = theme::small_px(m);
    let numeral = theme::numeral_px(m);

    fonts.draw_centered(
        pm,
        Face::Semibold,
        "Results",
        w / 2.0,
        m * theme::TOP_INSET - rise,
        small,
        theme::HEADING.fade(a),
    );

    // Close control, top right.
    let inset = m * theme::CORNER_INSET;
    let arm = m * 0.011;
    let cx = w - inset;
    let cy = inset;
    view.close_rect = Rect { x: cx - arm * 2.0, y: cy - arm * 2.0, w: arm * 4.0, h: arm * 4.0 };
    let close_col = if view.hover_close {
        theme::HEADING.fade(a)
    } else {
        theme::LABEL.fade(a * 0.8)
    };
    cross(pm, cx, cy - rise, arm, (1.4 * scale).max(1.0), close_col);

    // The two figures, straddling a hairline divider.
    let cap = fonts.cap_height(Face::Display, numeral);
    let baseline = h * theme::OPTICAL_CENTRE + cap / 2.0 - rise;
    let offset = m * theme::FIGURE_OFFSET;

    let wpm = test.wpm().to_string();
    let acc = format!("{}%", test.accuracy());
    fonts.draw_centered(
        pm,
        Face::Display,
        &wpm,
        w / 2.0 - offset,
        baseline,
        numeral,
        theme::NUMERAL.fade(a),
    );
    fonts.draw_centered(
        pm,
        Face::Display,
        &acc,
        w / 2.0 + offset,
        baseline,
        numeral,
        theme::NUMERAL.fade(a),
    );

    let dw = (1.0 * scale).max(1.0);
    fill_rect(
        pm,
        w / 2.0 - dw / 2.0,
        baseline - cap * 1.18,
        dw,
        cap * 1.55,
        theme::DIVIDER.fade(a),
    );

    let label_y = baseline + m * 0.030;
    fonts.draw_centered(
        pm,
        Face::Medium,
        "Words per Minute",
        w / 2.0 - offset,
        label_y,
        small,
        theme::LABEL.fade(a),
    );
    fonts.draw_centered(
        pm,
        Face::Medium,
        "Accuracy",
        w / 2.0 + offset,
        label_y,
        small,
        theme::LABEL.fade(a),
    );

    let secs = test.elapsed().as_secs_f32().round() as u32;
    let meta = format!("{}   ·   {} seconds", test.mode.label(), secs);
    fonts.draw_centered(
        pm,
        Face::Medium,
        &meta,
        w / 2.0,
        baseline + m * 0.098,
        small,
        theme::LABEL.fade(a * 0.85),
    );

    // The pill.
    let bw = m * 0.162;
    let bh = m * 0.047;
    let bx = (w - bw) / 2.0;
    let by = h - m * 0.022 - bh - rise;
    view.continue_rect = Rect { x: bx, y: by, w: bw, h: bh };
    let fillc = if view.hover_continue { theme::ACCENT_HOVER } else { theme::ACCENT };
    if let Some(p) = round_rect_path(bx, by, bw, bh, bh / 2.0) {
        fill(pm, &p, fillc.fade(a));
    }
    let cap_b = fonts.cap_height(Face::Semibold, small);
    fonts.draw_centered(
        pm,
        Face::Semibold,
        "Continue",
        w / 2.0,
        by + bh / 2.0 + cap_b / 2.0,
        small,
        theme::ON_ACCENT.fade(a),
    );
}

/// The close glyph, drawn as two strokes so it stays crisp at any size.
fn cross(pm: &mut PixmapMut, cx: f32, cy: f32, arm: f32, thickness: f32, color: Rgba) {
    let mut pb = PathBuilder::new();
    pb.move_to(cx - arm, cy - arm);
    pb.line_to(cx + arm, cy + arm);
    pb.move_to(cx + arm, cy - arm);
    pb.line_to(cx - arm, cy + arm);
    let Some(path) = pb.finish() else { return };
    let mut paint = Paint::default();
    paint.shader = Shader::SolidColor(color.to_color());
    paint.anti_alias = true;
    let stroke = tiny_skia::Stroke {
        width: thickness,
        line_cap: tiny_skia::LineCap::Round,
        ..Default::default()
    };
    pm.stroke_path(&path, &paint, &stroke, Transform::identity(), None);
}

/// Whether the view still has motion to render, so the loop knows to keep
/// asking for frames instead of going idle.
pub fn animating(test: &Test, view: &View, w: f32, h: f32, fonts: &mut Fonts) -> bool {
    if test.phase == Phase::Done {
        return view.reveal < 0.999;
    }
    let px = theme::prompt_px(theme::metric(w, h));
    let adv = fonts.advance(Face::Mono, 'm', px);
    let total = test.target.len() as f32 * adv;
    let pad = w * 0.06;
    let content = w - pad * 2.0;
    let scroll_target = if total <= content {
        (w - total) / 2.0
    } else {
        (w / 2.0 - test.cursor() as f32 * adv).clamp(w - pad - total, pad)
    };
    (view.scroll - scroll_target).abs() > 0.15
        || (view.caret - test.cursor() as f32 * adv).abs() > 0.15
}
