mod state;

fn main() {
    let t = state::Theme::load();
    println!("{} {} {:?}", t.scheme, t.mode, t.source);
}
