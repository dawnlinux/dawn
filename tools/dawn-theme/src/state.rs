//! Theme state — everything needed to reproduce the current palette.
//!
//! Lives at `~/.config/dawn/theme.toml`, which is outside every symlink Dawn
//! creates and is never touched by pacman.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// Where the palette is derived from.
///
/// Struct variants rather than newtypes: serde's internally-tagged
/// representation cannot serialise a newtype holding a bare string, and the
/// resulting TOML is more readable anyway —
///
/// ```toml
/// [source]
/// kind = "wallpaper"
/// path = "/home/you/Pictures/Wallpapers/dawn-black.png"
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Source {
    /// An image on disk.
    Wallpaper { path: PathBuf },
    /// A seed colour, as `#rrggbb`.
    Color { hex: String },
}

/// Everything needed to reproduce the current palette.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Theme {
    pub source: Source,
    pub scheme: String,
    pub mode: String,
    pub contrast: f32,
}

impl Default for Theme {
    /// Dawn's shipped identity.
    ///
    /// `scheme-monochrome` on `dawn-black.png` produces a near-black surface
    /// with a white accent, which is the palette the island was originally
    /// hand-tuned to — so a first run looks like a first boot.
    ///
    /// The wallpaper is addressed in `~/Pictures/Wallpapers` rather than under
    /// `/usr/share`, because `dawn link` seeds it there in BOTH package and
    /// dev mode. A `/usr/share` path would not exist on a developer's machine
    /// that has never installed the package.
    fn default() -> Self {
        Theme {
            source: Source::Wallpaper {
                path: home().join("Pictures/Wallpapers/dawn-black.png"),
            },
            scheme: "scheme-monochrome".into(),
            mode: "dark".into(),
            contrast: 0.0,
        }
    }
}

fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").expect("HOME is not set"))
}

impl Theme {
    /// The directory holding `theme.toml` and the generated output.
    pub fn dir() -> PathBuf {
        std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home().join(".config"))
            .join("dawn")
    }

    pub fn load() -> Theme {
        Theme::load_from(&Theme::dir())
    }

    /// Never fails.
    ///
    /// A fresh install has no state file, and a corrupt one is not a reason to
    /// leave someone without a desktop — both fall back to the shipped
    /// default.
    pub fn load_from(dir: &Path) -> Theme {
        std::fs::read_to_string(dir.join("theme.toml"))
            .ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> std::io::Result<()> {
        self.save_to(&Theme::dir())
    }

    pub fn save_to(&self, dir: &Path) -> std::io::Result<()> {
        std::fs::create_dir_all(dir)?;
        let body = toml::to_string_pretty(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        std::fs::write(dir.join("theme.toml"), body)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};

    static N: AtomicU32 = AtomicU32::new(0);

    fn tmp() -> PathBuf {
        let d = std::env::temp_dir().join(format!(
            "dawn-theme-{}-{}",
            std::process::id(),
            N.fetch_add(1, Ordering::SeqCst)
        ));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn round_trips_a_wallpaper_source() {
        let dir = tmp();
        let t = Theme {
            source: Source::Wallpaper {
                path: "/tmp/a.png".into(),
            },
            scheme: "scheme-vibrant".into(),
            mode: "dark".into(),
            contrast: 0.25,
        };
        t.save_to(&dir).unwrap();
        let back = Theme::load_from(&dir);
        assert_eq!(back, t);
    }

    #[test]
    fn round_trips_a_colour_source() {
        let dir = tmp();
        let t = Theme {
            source: Source::Color {
                hex: "#ff0000".into(),
            },
            ..Theme::default()
        };
        t.save_to(&dir).unwrap();
        assert_eq!(
            Theme::load_from(&dir).source,
            Source::Color {
                hex: "#ff0000".into()
            }
        );
    }

    #[test]
    fn missing_state_falls_back_to_the_default_rather_than_failing() {
        // A fresh install has no theme.toml and must still produce a desktop.
        let back = Theme::load_from(&tmp().join("does-not-exist"));
        assert_eq!(back.scheme, "scheme-monochrome");
        assert_eq!(back.mode, "dark");
    }

    #[test]
    fn corrupt_state_falls_back_rather_than_failing() {
        let dir = tmp();
        std::fs::write(dir.join("theme.toml"), b"this is not toml {{{").unwrap();
        assert_eq!(Theme::load_from(&dir).scheme, "scheme-monochrome");
    }

    #[test]
    fn the_default_wallpaper_is_the_one_dawn_link_seeds() {
        // Not a /usr/share path: that does not exist on a machine which has
        // only ever run `dawn dev`.
        match Theme::default().source {
            Source::Wallpaper { path: p } => {
                assert!(
                    p.ends_with("Pictures/Wallpapers/dawn-black.png"),
                    "got {p:?}"
                );
                assert!(!p.starts_with("/usr/share"));
            }
            other => panic!("default should be a wallpaper, got {other:?}"),
        }
    }

    #[test]
    fn save_creates_the_directory_if_it_is_absent() {
        let dir = tmp().join("nested/deeper");
        Theme::default().save_to(&dir).unwrap();
        assert!(dir.join("theme.toml").exists());
    }
}

#[cfg(test)]
mod shape {
    use super::*;
    #[test]
    fn serialised_shape_is_readable() {
        let body = toml::to_string_pretty(&Theme::default()).unwrap();
        println!("{body}");
        assert!(body.contains("kind = \"wallpaper\""));
        assert!(body.contains("scheme = \"scheme-monochrome\""));
    }
}
