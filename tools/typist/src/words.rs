//! The word pool and a small PRNG, so the binary needs no random-number crate.

/// The 200 most common English words, which is what makes a typing test measure
/// typing rather than reading.
pub const WORDS: [&str; 200] = [
    "the", "be", "of", "and", "a", "to", "in", "he", "have", "it", "that", "for", "they", "i",
    "with", "as", "not", "on", "she", "at", "by", "this", "we", "you", "do", "but", "from", "or",
    "which", "one", "would", "all", "will", "there", "say", "who", "make", "when", "can", "more",
    "if", "no", "man", "out", "other", "so", "what", "time", "up", "go", "about", "than", "into",
    "could", "state", "only", "new", "year", "some", "take", "come", "these", "know", "see", "use",
    "get", "like", "then", "first", "any", "work", "now", "may", "such", "give", "over", "think",
    "most", "even", "find", "day", "also", "after", "way", "many", "must", "look", "before",
    "great", "back", "through", "long", "where", "much", "should", "well", "people", "down", "own",
    "just", "because", "good", "each", "those", "feel", "seem", "how", "high", "too", "place",
    "little", "world", "very", "still", "nation", "hand", "old", "life", "tell", "write",
    "become", "here", "show", "house", "both", "between", "need", "mean", "call", "develop",
    "under", "last", "right", "move", "thing", "general", "school", "never", "same", "another",
    "begin", "while", "number", "part", "turn", "real", "leave", "might", "want", "point", "form",
    "off", "child", "few", "small", "since", "against", "ask", "late", "home", "interest", "large",
    "person", "end", "open", "public", "follow", "during", "present", "without", "again", "hold",
    "govern", "around", "possible", "head", "consider", "word", "program", "problem", "however",
    "lead", "system", "set", "order", "eye", "plan", "run", "keep", "face", "fact", "group",
    "play", "stand", "increase", "early", "course", "change", "help", "line",
];

/// SplitMix64. Small, fast, and good enough for shuffling a word list.
pub struct Rng(u64);

impl Rng {
    pub fn from_entropy() -> Self {
        // Nanosecond wall clock mixed with the address of a stack local, which
        // varies per process under ASLR.
        let t = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x9E3779B97F4A7C15);
        let stack = &t as *const u64 as u64;
        Rng(t ^ stack.rotate_left(17))
    }

    pub fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }

    /// Uniform in `0..n`, using Lemire's multiply-shift.
    pub fn below(&mut self, n: usize) -> usize {
        ((self.next_u64() as u128 * n as u128) >> 64) as usize
    }
}

/// Pick `count` words, avoiding an immediate repeat so the line never reads
/// like a stutter.
pub fn pick(count: usize, rng: &mut Rng) -> Vec<&'static str> {
    let mut out: Vec<&'static str> = Vec::with_capacity(count);
    for _ in 0..count {
        let mut w = WORDS[rng.below(WORDS.len())];
        if out.last() == Some(&w) {
            w = WORDS[rng.below(WORDS.len())];
        }
        out.push(w);
    }
    out
}
