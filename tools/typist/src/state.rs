//! The typing test itself: what to type, what was typed, and what that scores.

use std::time::{Duration, Instant};

use crate::words::{pick, Rng};

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// Finish after a fixed number of words.
    Words(usize),
    /// Finish after a fixed number of seconds, with an endless supply of words.
    Time(u32),
}

impl Mode {
    pub fn label(self) -> String {
        match self {
            Mode::Words(n) => format!("{n} words"),
            Mode::Time(s) => format!("{s} second test"),
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Phase {
    /// Nothing typed yet; the clock has not started.
    Idle,
    Running,
    Done,
}

/// How many characters of runway to keep ahead of the caret in timed mode.
const RUNWAY: usize = 120;

pub struct Test {
    pub mode: Mode,
    pub phase: Phase,
    /// The characters to be typed, words joined by single spaces.
    pub target: Vec<char>,
    /// What was actually typed, index-aligned with `target`.
    pub input: Vec<char>,
    /// Total words in the target, for the `n/total` counter.
    pub words_total: usize,
    /// Every keypress that produced a character, including wrong ones.
    keystrokes: u32,
    /// How many of those were wrong on first attempt.
    errors: u32,
    started: Option<Instant>,
    finished: Option<Instant>,
    rng: Rng,
}

impl Test {
    pub fn new(mode: Mode) -> Self {
        let mut t = Test {
            mode,
            phase: Phase::Idle,
            target: Vec::new(),
            input: Vec::new(),
            words_total: 0,
            keystrokes: 0,
            errors: 0,
            started: None,
            finished: None,
            rng: Rng::from_entropy(),
        };
        t.reset();
        t
    }

    /// Start over with a freshly drawn set of words.
    pub fn reset(&mut self) {
        let count = match self.mode {
            Mode::Words(n) => n,
            // Enough that a fast typist never sees the seam; topped up anyway.
            Mode::Time(s) => (s as usize).max(15) * 3,
        };
        let words = pick(count, &mut self.rng);
        self.words_total = words.len();
        self.target = words.join(" ").chars().collect();
        self.input.clear();
        self.keystrokes = 0;
        self.errors = 0;
        self.started = None;
        self.finished = None;
        self.phase = Phase::Idle;
    }

    pub fn cursor(&self) -> usize {
        self.input.len()
    }

    /// Whether the character at `i` was typed correctly. Only meaningful for
    /// indices below the caret.
    pub fn correct_at(&self, i: usize) -> bool {
        self.input.get(i) == self.target.get(i)
    }

    /// 1-based index of the word the caret sits in.
    pub fn word_index(&self) -> usize {
        let spaces = self.target[..self.cursor().min(self.target.len())]
            .iter()
            .filter(|c| **c == ' ')
            .count();
        (spaces + 1).min(self.words_total)
    }

    /// Seconds remaining in timed mode.
    pub fn remaining(&self) -> u32 {
        match self.mode {
            Mode::Time(limit) => {
                let used = self.elapsed().as_secs_f32();
                (limit as f32 - used).max(0.0).ceil() as u32
            }
            Mode::Words(_) => 0,
        }
    }

    pub fn elapsed(&self) -> Duration {
        match (self.started, self.finished) {
            (Some(s), Some(f)) => f.saturating_duration_since(s),
            (Some(s), None) => s.elapsed(),
            _ => Duration::ZERO,
        }
    }

    /// Accept a printable character. Returns true if anything changed.
    pub fn type_char(&mut self, ch: char) -> bool {
        if self.phase == Phase::Done || self.cursor() >= self.target.len() {
            return false;
        }
        if self.phase == Phase::Idle {
            self.phase = Phase::Running;
            self.started = Some(Instant::now());
        }

        let expected = self.target[self.cursor()];
        self.keystrokes += 1;
        if ch != expected {
            self.errors += 1;
        }
        self.input.push(ch);

        if let Mode::Time(_) = self.mode {
            self.top_up();
        }
        if self.cursor() >= self.target.len() {
            if let Mode::Words(_) = self.mode {
                self.finish();
            }
        }
        true
    }

    /// Delete one character, or the whole preceding word when `word` is set.
    pub fn backspace(&mut self, word: bool) -> bool {
        if self.phase == Phase::Done || self.input.is_empty() {
            return false;
        }
        if word {
            // Eat trailing spaces, then the word body.
            while self.input.last() == Some(&' ') {
                self.input.pop();
            }
            while let Some(c) = self.input.last() {
                if *c == ' ' {
                    break;
                }
                self.input.pop();
            }
        } else {
            self.input.pop();
        }
        true
    }

    /// End a timed run if its clock has expired. Returns true if it just ended.
    pub fn tick(&mut self) -> bool {
        if self.phase != Phase::Running {
            return false;
        }
        if let Mode::Time(limit) = self.mode {
            if self.elapsed() >= Duration::from_secs(limit as u64) {
                self.finish();
                return true;
            }
        }
        false
    }

    fn finish(&mut self) {
        // Clamp a timed run to its nominal length so the score is not diluted
        // by the few milliseconds between expiry and the next tick.
        if let Mode::Time(limit) = self.mode {
            if let Some(s) = self.started {
                self.finished = Some(s + Duration::from_secs(limit as u64));
            }
        } else {
            self.finished = Some(Instant::now());
        }
        self.phase = Phase::Done;
    }

    /// Keep a comfortable margin of unseen words ahead of the caret.
    fn top_up(&mut self) {
        if self.target.len().saturating_sub(self.cursor()) > RUNWAY {
            return;
        }
        let more = pick(20, &mut self.rng);
        self.words_total += more.len();
        self.target.push(' ');
        self.target.extend(more.join(" ").chars());
    }

    /// Characters typed correctly, which is what words-per-minute is built on.
    fn correct_chars(&self) -> u32 {
        (0..self.input.len()).filter(|i| self.correct_at(*i)).count() as u32
    }

    /// Net words per minute, using the standard five-characters-to-a-word.
    pub fn wpm(&self) -> u32 {
        let mins = self.elapsed().as_secs_f64() / 60.0;
        if mins <= 0.0 {
            return 0;
        }
        ((self.correct_chars() as f64 / 5.0) / mins).round().max(0.0) as u32
    }

    /// Share of keystrokes that hit the right character.
    pub fn accuracy(&self) -> u32 {
        if self.keystrokes == 0 {
            return 100;
        }
        let good = self.keystrokes.saturating_sub(self.errors) as f64;
        ((good / self.keystrokes as f64) * 100.0).round() as u32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Run `input` against a known `target`, then pin the clock to `secs`.
    fn run(target: &str, input: &str, secs: u64) -> Test {
        let mut t = Test::new(Mode::Words(1));
        t.target = target.chars().collect();
        t.words_total = target.split(' ').count();
        for ch in input.chars() {
            t.type_char(ch);
        }
        let now = Instant::now();
        t.started = Some(now - Duration::from_secs(secs));
        t.finished = Some(now);
        t
    }

    #[test]
    fn wpm_counts_five_characters_to_a_word() {
        // 60 correct characters in one minute is twelve words a minute.
        let t = run(&"a".repeat(60), &"a".repeat(60), 60);
        assert_eq!(t.wpm(), 12);
    }

    #[test]
    fn wpm_ignores_characters_typed_wrongly() {
        // Half the characters are wrong, so half the speed.
        let input: String = "ab".repeat(30);
        let t = run(&"a".repeat(60), &input, 60);
        assert_eq!(t.wpm(), 6);
    }

    #[test]
    fn wpm_is_zero_before_the_clock_starts() {
        let t = Test::new(Mode::Words(5));
        assert_eq!(t.wpm(), 0);
    }

    #[test]
    fn accuracy_is_measured_over_keystrokes_not_the_final_text() {
        // Longer than the input, so the test stays open for the correction.
        let mut t = run("aaaaaaaa", "abaa", 10);
        assert_eq!(t.accuracy(), 75);
        // Correcting the mistake does not undo it; the keystroke still happened.
        t.backspace(false);
        t.backspace(false);
        t.backspace(false);
        t.type_char('a');
        t.type_char('a');
        t.type_char('a');
        assert_eq!(t.input.iter().collect::<String>(), "aaaa");
        // Seven keystrokes, one of them wrong.
        assert_eq!(t.accuracy(), 86);
    }

    #[test]
    fn a_finished_test_ignores_further_input() {
        let mut t = run("go", "go", 10);
        assert_eq!(t.phase, Phase::Done);
        assert!(!t.backspace(false));
        assert!(!t.type_char('x'));
        assert_eq!(t.cursor(), 2);
    }

    #[test]
    fn accuracy_starts_at_a_hundred() {
        assert_eq!(Test::new(Mode::Words(5)).accuracy(), 100);
    }

    #[test]
    fn a_wrong_character_still_advances_the_caret() {
        let t = run("hello", "hXllo", 10);
        assert_eq!(t.cursor(), 5);
        assert!(!t.correct_at(1));
        assert!(t.correct_at(2));
    }

    #[test]
    fn word_counter_tracks_the_caret() {
        let mut t = Test::new(Mode::Words(3));
        t.target = "one two six".chars().collect();
        t.words_total = 3;
        assert_eq!(t.word_index(), 1);
        for ch in "one ".chars() {
            t.type_char(ch);
        }
        assert_eq!(t.word_index(), 2);
        for ch in "two ".chars() {
            t.type_char(ch);
        }
        assert_eq!(t.word_index(), 3);
    }

    #[test]
    fn word_mode_finishes_on_the_last_character() {
        let mut t = Test::new(Mode::Words(2));
        t.target = "go on".chars().collect();
        t.words_total = 2;
        for ch in "go o".chars() {
            t.type_char(ch);
        }
        assert_eq!(t.phase, Phase::Running);
        t.type_char('n');
        assert_eq!(t.phase, Phase::Done);
        // Further input is refused once the test is over.
        assert!(!t.type_char('x'));
    }

    #[test]
    fn ctrl_backspace_deletes_a_whole_word() {
        let mut t = Test::new(Mode::Words(3));
        t.target = "one two six".chars().collect();
        for ch in "one two".chars() {
            t.type_char(ch);
        }
        t.backspace(true);
        assert_eq!(t.input.iter().collect::<String>(), "one ");
        t.backspace(true);
        assert_eq!(t.cursor(), 0);
        // Backspacing an empty line is a no-op rather than an underflow.
        assert!(!t.backspace(true));
    }

    #[test]
    fn timed_mode_ends_when_the_clock_runs_out() {
        let mut t = Test::new(Mode::Time(1));
        assert!(!t.tick(), "an unstarted test has no clock to expire");
        t.type_char(t.target[0]);
        assert_eq!(t.phase, Phase::Running);
        // Back-date the start so the limit has already passed.
        t.started = Some(Instant::now() - Duration::from_secs(2));
        assert!(t.tick());
        assert_eq!(t.phase, Phase::Done);
        // The score is measured over the nominal duration, not the overshoot,
        // so a late tick cannot dilute it.
        assert_eq!(t.elapsed(), Duration::from_secs(1));
        assert!(!t.tick(), "a finished test does not expire twice");
    }

    #[test]
    fn timed_mode_counts_down() {
        let mut t = Test::new(Mode::Time(30));
        t.type_char(t.target[0]);
        t.started = Some(Instant::now() - Duration::from_secs(10));
        assert_eq!(t.remaining(), 20);
    }

    #[test]
    fn timed_mode_keeps_words_ahead_of_the_caret() {
        let mut t = Test::new(Mode::Time(15));
        let start_len = t.target.len();
        // Type to within the runway of the end and the pool must have grown.
        let to_type: String =
            t.target[..start_len - RUNWAY / 2].iter().collect();
        for ch in to_type.chars() {
            t.type_char(ch);
        }
        assert!(t.target.len() > start_len);
        assert_eq!(t.phase, Phase::Running);
    }
}
