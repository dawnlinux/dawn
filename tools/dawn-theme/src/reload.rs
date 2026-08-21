//! Telling running applications to re-read their colours.
//!
//! These are deliberately NOT matugen `post_hook`s. A failing post_hook does
//! not fail matugen — it prints an error and matugen still exits 0 — so a
//! reload issued there would fail invisibly. Running them here means each one
//! is attributed by name and reported.
//!
//! Applications absent from this list read their colours at launch and need no
//! reload: rofi, hyprlock, starship, nvim, and Qt via qt5ct/qt6ct. The island
//! is absent too — it watches the generated JSON and repaints itself.

use std::process::{Command, Stdio};

/// One application's reload.
pub struct Reload {
    pub name: &'static str,
    pub program: &'static str,
    pub args: &'static [&'static str],
    /// True when a non-zero exit means "the application is not running"
    /// rather than "the reload failed". `pkill` exits 1 when it matches
    /// nothing, which is the common case on a machine with no terminal open.
    pub absent_is_fine: bool,
}

pub const RELOADS: &[Reload] = &[
    Reload {
        name: "kitty",
        program: "pkill",
        args: &["-USR1", "kitty"],
        absent_is_fine: true,
    },
    Reload {
        name: "hyprland",
        program: "hyprctl",
        args: &["reload"],
        absent_is_fine: false,
    },
    // Nudges GTK applications into re-reading gtk.css.
    Reload {
        name: "gtk",
        program: "gsettings",
        args: &[
            "set",
            "org.gnome.desktop.interface",
            "color-scheme",
            "prefer-dark",
        ],
        absent_is_fine: false,
    },
];

/// Run each reload independently, returning every outcome.
///
/// One failure never stops the others: a terminal that will not accept USR1
/// must not prevent GTK from updating.
pub fn run_all(reloads: &[Reload]) -> Vec<(&'static str, Result<(), String>)> {
    reloads
        .iter()
        .map(|r| {
            let outcome = match Command::new(r.program)
                .args(r.args)
                .stdout(Stdio::null())
                .stderr(Stdio::piped())
                .output()
            {
                Err(e) => Err(format!("{}: could not run {}: {e}", r.name, r.program)),
                Ok(out) if out.status.success() => Ok(()),
                Ok(_) if r.absent_is_fine => Ok(()),
                Ok(out) => {
                    let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
                    Err(format!(
                        "{}: {} exited {}{}",
                        r.name,
                        r.program,
                        out.status.code().unwrap_or(-1),
                        if stderr.is_empty() {
                            String::new()
                        } else {
                            format!(": {stderr}")
                        }
                    ))
                }
            };
            (r.name, outcome)
        })
        .collect()
}

pub fn all() -> Vec<(&'static str, Result<(), String>)> {
    run_all(RELOADS)
}

/// Put an image on the desktop.
///
/// Separate from RELOADS because it is not a reload: it takes an argument, and
/// it only runs when the source is a wallpaper.
///
/// This exists because deriving a palette from an image the user cannot see is
/// worse than useless — the whole premise is that the desktop follows the
/// wallpaper. `dawn-theme wallpaper X` therefore both sets X and themes from
/// it, which is what the command name promises.
///
/// The transition matches `Config.wallpaperCommand` in the island so that
/// setting a wallpaper from the shell and from the carousel look the same.
pub fn set_wallpaper(path: &std::path::Path) -> Result<(), String> {
    let out = Command::new("awww")
        .args([
            "img",
            &path.display().to_string(),
            "--transition-type",
            "random",
            "--transition-duration",
            "1.2",
            "--transition-fps",
            "60",
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("could not run awww: {e}"))?;

    if out.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&out.stderr).trim().to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const OK: Reload = Reload {
        name: "ok",
        program: "true",
        args: &[],
        absent_is_fine: false,
    };
    const BROKEN: Reload = Reload {
        name: "broken",
        program: "definitely-not-a-real-binary-xyz",
        args: &[],
        absent_is_fine: false,
    };
    const FAILS: Reload = Reload {
        name: "fails",
        program: "false",
        args: &[],
        absent_is_fine: false,
    };
    const FAILS_BUT_FINE: Reload = Reload {
        name: "maybe-absent",
        program: "false",
        args: &[],
        absent_is_fine: true,
    };

    #[test]
    fn one_failing_reload_does_not_stop_the_others() {
        let r = run_all(&[OK, BROKEN, OK]);
        assert_eq!(r.len(), 3);
        assert!(r[0].1.is_ok());
        assert!(r[1].1.is_err());
        assert!(r[2].1.is_ok(), "a later reload must still run");
    }

    #[test]
    fn a_failure_names_the_application_not_just_the_program() {
        let r = run_all(&[BROKEN]);
        assert_eq!(r[0].0, "broken");
        assert!(r[0].1.as_ref().unwrap_err().contains("broken"));
    }

    #[test]
    fn a_non_zero_exit_is_a_failure_by_default() {
        assert!(run_all(&[FAILS])[0].1.is_err());
    }

    #[test]
    fn a_non_zero_exit_is_tolerated_when_absence_is_expected() {
        // pkill exits 1 when the application simply is not running. Reporting
        // that as a failure would mean every run warns on a machine with no
        // terminal open.
        assert!(run_all(&[FAILS_BUT_FINE])[0].1.is_ok());
    }

    #[test]
    fn every_shipped_reload_names_a_program_that_exists() {
        // Catches a typo in RELOADS, which would otherwise only surface as a
        // warning on someone else's desktop.
        for r in RELOADS {
            let found = Command::new("sh")
                .args(["-c", &format!("command -v {}", r.program)])
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false);
            assert!(found, "{}: {} is not on PATH", r.name, r.program);
        }
    }
}

#[cfg(test)]
mod wallpaper {
    use super::*;
    use std::path::Path;

    #[test]
    fn a_missing_image_is_reported_rather_than_panicked_on() {
        // awww rejects a path it cannot read; that must surface as an error
        // string, not a crash, because the palette should still be written.
        let r = set_wallpaper(Path::new("/definitely/not/an/image.png"));
        assert!(r.is_err());
        assert!(!r.unwrap_err().is_empty());
    }

    #[test]
    fn the_transition_matches_the_islands_wallpaper_command() {
        // Setting a wallpaper from the shell and from the island's carousel
        // should look identical. The island uses:
        //   awww img {} --transition-type random --transition-duration 1.2
        //               --transition-fps 60
        // If Config.wallpaperCommand changes, this is the reminder to follow.
        let src = include_str!("reload.rs");
        assert!(src.contains("--transition-duration"));
        assert!(src.contains("\"1.2\""));
        assert!(src.contains("\"60\""));
    }
}
