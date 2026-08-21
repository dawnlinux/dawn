//! dawn-theme — Dawn's colour engine.
//!
//! Owns the theme state, drives matugen, and reloads the desktop.
//!
//! Reloads are issued here rather than as matugen `post_hook`s because a
//! failing post_hook does not fail matugen: it prints an error and matugen
//! still exits 0, so a caller cannot learn whether the desktop actually picked
//! the change up.

mod reload;
mod render;
mod state;

use clap::{Parser, Subcommand};
use state::{Source, Theme};
use std::path::PathBuf;
use std::process::ExitCode;

/// matugen's nine schemes. Checked here so a typo is a clear error rather
/// than a matugen usage dump.
const SCHEMES: &[&str] = &[
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot",
    "scheme-vibrant",
];

#[derive(Parser)]
#[command(name = "dawn-theme", version, about = "Dawn's colour engine")]
struct Cli {
    /// matugen config. Defaults to the one belonging to whichever mode
    /// `dawn` has this machine in — the packaged config, or the checkout's
    /// when running `dawn dev`.
    #[arg(long)]
    config: Option<PathBuf>,

    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Derive the palette from an image.
    Wallpaper { path: PathBuf },
    /// Derive the palette from a seed colour, as #rrggbb.
    Color { hex: String },
    /// One of matugen's nine schemes, with or without the `scheme-` prefix.
    Scheme { name: String },
    /// dark or light.
    Mode { mode: String },
    /// -1.0 (minimum) to 1.0 (maximum).
    Contrast { value: f32 },
    /// Print the current state as JSON.
    Status,
    /// Re-render from stored state, changing nothing.
    Apply,
}

fn fail(msg: impl AsRef<str>) -> ExitCode {
    eprintln!("error: {}", msg.as_ref());
    ExitCode::FAILURE
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let config = cli.config.unwrap_or_else(Theme::matugen_config);
    let mut theme = Theme::load();

    match cli.command {
        Cmd::Wallpaper { path } => match path.canonicalize() {
            // Canonicalised so the stored state survives being run from a
            // different directory, and so a typo fails now rather than inside
            // matugen.
            Ok(path) => theme.source = Source::Wallpaper { path },
            Err(e) => return fail(format!("{}: {e}", path.display())),
        },

        Cmd::Color { hex } => {
            let hex = if hex.starts_with('#') {
                hex
            } else {
                format!("#{hex}")
            };
            if hex.len() != 7 || !hex[1..].chars().all(|c| c.is_ascii_hexdigit()) {
                return fail(format!("not a #rrggbb colour: {hex}"));
            }
            theme.source = Source::Color { hex };
        }

        Cmd::Scheme { name } => {
            let name = if name.starts_with("scheme-") {
                name
            } else {
                format!("scheme-{name}")
            };
            if !SCHEMES.contains(&name.as_str()) {
                eprintln!("error: unknown scheme: {name}");
                eprintln!("       one of: {}", SCHEMES.join(", "));
                return ExitCode::FAILURE;
            }
            theme.scheme = name;
        }

        Cmd::Mode { mode } => {
            if mode != "dark" && mode != "light" {
                return fail(format!("mode must be dark or light, not {mode}"));
            }
            theme.mode = mode;
        }

        Cmd::Contrast { value } => {
            if !(-1.0..=1.0).contains(&value) {
                return fail(format!(
                    "contrast must be between -1.0 and 1.0, not {value}"
                ));
            }
            theme.contrast = value;
        }

        Cmd::Status => {
            println!("{}", serde_json::to_string_pretty(&theme).unwrap());
            return ExitCode::SUCCESS;
        }

        Cmd::Apply => {}
    }

    // Render BEFORE saving. State is only recorded once matugen has actually
    // produced the templates, so a failed run leaves the previous palette in
    // place and theme.toml still describing it.
    if let Err(e) = render::run(&theme, &config) {
        return fail(format!("matugen failed:\n{e}"));
    }
    if let Err(e) = theme.save() {
        return fail(format!("rendered, but could not save state: {e}"));
    }

    // Reload failures are warnings, not errors. The palette is on disk; a
    // terminal that would not accept a signal does not undo that, and exiting
    // non-zero here would make a caller think nothing happened.
    let mut failed = 0;
    for (name, outcome) in reload::all() {
        if let Err(e) = outcome {
            eprintln!("warning: {name} did not reload: {e}");
            failed += 1;
        }
    }
    if failed > 0 {
        eprintln!("{failed} application(s) did not reload; the palette is written regardless");
    }

    ExitCode::SUCCESS
}
