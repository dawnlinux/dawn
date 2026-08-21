//! Building and running the matugen invocation.
//!
//! `args` is split out from `run` so the command line can be asserted on
//! without a matugen binary present. The flags are the part that goes wrong.

use crate::state::{Source, Theme};
use std::path::Path;
use std::process::Command;

/// Build the matugen argument list.
///
/// Order matters: matugen uses clap, so global options come before the
/// subcommand, and the subcommand's positional arguments come last.
pub fn args(theme: &Theme, config: &Path) -> Vec<String> {
    let mut a: Vec<String> = vec![
        "--config".into(),
        config.display().to_string(),
        // NOT optional. matugen 4.1 refuses to run on an image with multiple
        // candidate colours when no terminal is detected:
        //
        //   Multiple source colors found, no preference was inputted,
        //   and a terminal was not detected.
        //
        // dawn-theme is always headless — invoked from the shell, a keybind
        // or a service — so this is passed on every run.
        "--prefer".into(),
        "saturation".into(),
        "--mode".into(),
        theme.mode.clone(),
        "--type".into(),
        theme.scheme.clone(),
    ];

    // Sent only when it differs from the default. Passing `--contrast 0` is
    // accepted, but it makes the command line claim an adjustment that is not
    // being made.
    if theme.contrast != 0.0 {
        a.push("--contrast".into());
        a.push(theme.contrast.to_string());
    }

    match &theme.source {
        Source::Wallpaper { path } => {
            a.push("image".into());
            a.push(path.display().to_string());
        }
        Source::Color { hex } => {
            a.push("color".into());
            a.push("hex".into());
            a.push(hex.clone());
        }
    }
    a
}

/// Run matugen, returning its stderr on failure.
///
/// A successful return means the TEMPLATES RENDERED. It does not mean the
/// desktop picked the change up: matugen exits 0 even when a `post_hook`
/// fails. Reloads are issued separately, by the reload module, which reports
/// its own failures.
pub fn run(theme: &Theme, config: &Path) -> Result<(), String> {
    let a = args(theme, config);

    let out = Command::new("matugen")
        .args(&a)
        .output()
        .map_err(|e| format!("could not run matugen: {e}"))?;

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
        return Err(if stderr.is_empty() {
            format!("matugen exited {}", out.status.code().unwrap_or(-1))
        } else {
            stderr
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::{Source, Theme};
    use std::path::PathBuf;

    fn cfg() -> PathBuf {
        PathBuf::from("/tmp/config.toml")
    }

    fn flag<'a>(a: &'a [String], name: &str) -> Option<&'a str> {
        a.iter().position(|x| x == name).map(|i| a[i + 1].as_str())
    }

    #[test]
    fn always_passes_prefer_because_matugen_refuses_without_a_tty() {
        assert_eq!(
            flag(&args(&Theme::default(), &cfg()), "--prefer"),
            Some("saturation")
        );
    }

    #[test]
    fn never_passes_source_color_index_which_does_not_exist_in_matugen_4_1() {
        // The reference implementation this design drew on uses that flag.
        // It was removed upstream; passing it makes matugen exit non-zero.
        let a = args(&Theme::default(), &cfg());
        assert!(!a.iter().any(|x| x == "--source-color-index"));
    }

    #[test]
    fn wallpaper_source_ends_with_the_image_subcommand() {
        let t = Theme {
            source: Source::Wallpaper {
                path: "/tmp/w.png".into(),
            },
            ..Theme::default()
        };
        let a = args(&t, &cfg());
        assert_eq!(
            &a[a.len() - 2..],
            &["image".to_string(), "/tmp/w.png".to_string()]
        );
    }

    #[test]
    fn colour_source_ends_with_the_color_hex_subcommand() {
        let t = Theme {
            source: Source::Color {
                hex: "#ff0000".into(),
            },
            ..Theme::default()
        };
        let a = args(&t, &cfg());
        assert_eq!(
            &a[a.len() - 3..],
            &[
                "color".to_string(),
                "hex".to_string(),
                "#ff0000".to_string()
            ]
        );
    }

    #[test]
    fn zero_contrast_is_omitted_rather_than_sent_as_zero() {
        let t = Theme {
            contrast: 0.0,
            ..Theme::default()
        };
        assert!(!args(&t, &cfg()).iter().any(|x| x == "--contrast"));

        let t = Theme {
            contrast: 0.5,
            ..Theme::default()
        };
        assert_eq!(flag(&args(&t, &cfg()), "--contrast"), Some("0.5"));
    }

    #[test]
    fn scheme_mode_and_config_are_always_sent() {
        let a = args(&Theme::default(), &cfg());
        assert_eq!(flag(&a, "--type"), Some("scheme-monochrome"));
        assert_eq!(flag(&a, "--mode"), Some("dark"));
        assert_eq!(flag(&a, "--config"), Some("/tmp/config.toml"));
    }

    #[test]
    fn global_options_precede_the_subcommand() {
        // clap requires it, and getting this wrong produces an unhelpful
        // "unexpected argument" rather than anything diagnostic.
        let a = args(&Theme::default(), &cfg());
        let subcommand = a.iter().position(|x| x == "image" || x == "color").unwrap();
        for name in ["--config", "--prefer", "--mode", "--type"] {
            assert!(
                a.iter().position(|x| x == name).unwrap() < subcommand,
                "{name} must come before the subcommand"
            );
        }
    }

    #[test]
    fn a_missing_matugen_binary_is_reported_not_panicked_on() {
        // The error path people actually hit: the package is not installed.
        let err = run(&Theme::default(), Path::new("/nonexistent/config.toml"))
            .err()
            .expect("should fail without a config");
        assert!(!err.is_empty());
    }
}

#[cfg(test)]
mod against_real_matugen {
    use super::*;
    use crate::state::{Source, Theme};
    use std::path::PathBuf;

    /// The argument list this module builds must actually be accepted by the
    /// installed matugen. Asserting on our own strings only proves we are
    /// self-consistent; this proves we are correct.
    ///
    /// Skipped when matugen is absent so the suite still runs in CI images
    /// that do not have it.
    #[test]
    fn the_built_arguments_are_accepted_by_the_installed_matugen() {
        if Command::new("matugen").arg("--version").output().is_err() {
            eprintln!("matugen not installed — skipping");
            return;
        }

        let wallpaper = PathBuf::from(std::env::var("HOME").unwrap())
            .join("Pictures/Wallpapers/dawn-black.png");
        if !wallpaper.exists() {
            eprintln!("no shipped wallpaper to test with — skipping");
            return;
        }

        // matugen REQUIRES at least one [templates.*] — a bare [config] is
        // rejected with "missing field `templates`". So the fixture renders a
        // single throwaway template into a temp directory.
        let dir = std::env::temp_dir().join("dawn-theme-argcheck");
        std::fs::create_dir_all(&dir).unwrap();
        let tpl = dir.join("probe.txt");
        std::fs::write(&tpl, "{{colors.primary.default.hex}}\n").unwrap();

        let cfg = dir.join("config.toml");
        std::fs::write(
            &cfg,
            format!(
                "[config]\n\n[templates.probe]\ninput_path = '{}'\noutput_path = '{}'\n",
                tpl.display(),
                dir.join("out.txt").display()
            ),
        )
        .unwrap();

        for theme in [
            Theme {
                source: Source::Wallpaper { path: wallpaper },
                ..Theme::default()
            },
            Theme {
                source: Source::Color {
                    hex: "#7ec699".into(),
                },
                ..Theme::default()
            },
            Theme {
                scheme: "scheme-vibrant".into(),
                contrast: 0.4,
                ..Theme::default()
            },
        ] {
            let out = Command::new("matugen")
                .args(args(&theme, &cfg))
                .output()
                .expect("matugen should run");
            assert!(
                out.status.success(),
                "matugen rejected our arguments for {:?}:\n{}",
                theme.scheme,
                String::from_utf8_lossy(&out.stderr)
            );
        }
    }
}
