//! typist — a minimal typing test.
//!
//! Draws into a translucent Wayland surface with software rendering, so the
//! compositor's own blur shows through and no GPU context is ever created.

mod render;
mod state;
mod text;
mod theme;
mod words;

use std::time::{Duration, Instant};

use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState, FrameCallbackData},
    delegate_registry,
    output::{OutputHandler, OutputState},
    reexports::calloop::{
        timer::{TimeoutAction, Timer},
        EventLoop, LoopHandle,
    },
    reexports::calloop_wayland_source::WaylandSource,
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        keyboard::{KeyEvent, KeyboardHandler, Keysym, Modifiers, RawModifiers},
        pointer::{PointerEvent, PointerEventKind, PointerHandler},
        Capability, SeatHandler, SeatState,
    },
    shell::{
        xdg::{
            window::{Window, WindowConfigure, WindowDecorations, WindowHandler},
            XdgShell,
        },
        WaylandSurface,
    },
    shm::{
        slot::{Buffer, SlotPool},
        Shm, ShmHandler,
    },
};
use smithay_client_toolkit::reexports::client::{
    globals::registry_queue_init,
    protocol::{wl_keyboard, wl_output, wl_pointer, wl_seat, wl_shm, wl_surface},
    Connection, QueueHandle,
};
use tiny_skia::PixmapMut;

use render::View;
use state::{Mode, Phase, Test};
use text::Fonts;

const APP_ID: &str = "typist";
const DEFAULT_SIZE: (u32, u32) = (1100, 620);

/// The caret holds steady for this long after a keystroke before it resumes
/// blinking, so it never flickers mid-word.
const BLINK_HOLD: Duration = Duration::from_millis(700);
const BLINK_PERIOD: u128 = 1060;

/// Tick interval while something is moving, and while nothing is.
const TICK_ACTIVE: Duration = Duration::from_millis(8);
const TICK_IDLE: Duration = Duration::from_millis(100);

fn main() {
    let mode = match parse_args() {
        Ok(Some(m)) => m,
        Ok(None) => return,
        Err(e) => {
            eprintln!("typist: {e}");
            eprintln!("try `typist --help`");
            std::process::exit(2);
        }
    };

    let fonts = match Fonts::load() {
        Ok(f) => f,
        Err(e) => {
            eprintln!("typist: {e}");
            std::process::exit(1);
        }
    };

    let conn = match Connection::connect_to_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("typist: no Wayland display ({e})");
            std::process::exit(1);
        }
    };

    let (globals, event_queue) = registry_queue_init(&conn).expect("wayland registry");
    let qh: QueueHandle<App> = event_queue.handle();
    let mut event_loop: EventLoop<App> = EventLoop::try_new().expect("event loop");
    WaylandSource::new(conn.clone(), event_queue).insert(event_loop.handle()).unwrap();

    let compositor = CompositorState::bind(&globals, &qh).expect("wl_compositor");
    let xdg_shell = XdgShell::bind(&globals, &qh).expect("xdg_wm_base");
    let shm = Shm::bind(&globals, &qh).expect("wl_shm");

    let surface = compositor.create_surface(&qh);
    // Server-side decorations would draw a titlebar over a window that is meant
    // to be nothing but a pane of text.
    let window = xdg_shell.create_window(surface, WindowDecorations::RequestClient, &qh);
    window.set_title("typist");
    window.set_app_id(APP_ID);
    window.set_min_size(Some((480, 260)));
    window.commit();

    let pool = SlotPool::new(DEFAULT_SIZE.0 as usize * DEFAULT_SIZE.1 as usize * 4, &shm)
        .expect("shm pool");

    // Drive animation and the timed-mode clock from one adaptive timer.
    event_loop
        .handle()
        .insert_source(Timer::from_duration(TICK_IDLE), |_, _, app: &mut App| {
            TimeoutAction::ToDuration(app.tick())
        })
        .expect("timer source");

    let mut app = App {
        registry_state: RegistryState::new(&globals),
        seat_state: SeatState::new(&globals, &qh),
        output_state: OutputState::new(&globals, &qh),
        shm,
        pool,
        window,
        qh,
        keyboard: None,
        pointer: None,
        modifiers: Modifiers::default(),
        loop_handle: event_loop.handle(),

        exit: false,
        configured: false,
        width: DEFAULT_SIZE.0,
        height: DEFAULT_SIZE.1,
        scale: 1,
        buffer: None,

        fonts,
        test: Test::new(mode),
        view: View::default(),

        dirty: true,
        frame_ready: true,
        last_draw: Instant::now(),
        last_key: None,
        pointer_pos: (-1.0, -1.0),
    };

    while !app.exit {
        if event_loop.dispatch(Duration::from_millis(200), &mut app).is_err() {
            break;
        }
    }
}

fn parse_args() -> Result<Option<Mode>, String> {
    let mut mode = Mode::Words(25);
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                println!("typist — a minimal typing test\n");
                println!("usage: typist [-w N | -t SECONDS]\n");
                println!("  -w, --words N     finish after N words (default 25)");
                println!("  -t, --time S      finish after S seconds");
                println!("  -h, --help        show this message\n");
                println!("keys: tab restart · enter next test · esc quit");
                return Ok(None);
            }
            "-w" | "--words" => {
                let n = args.next().ok_or("-w needs a word count")?;
                let n: usize = n.parse().map_err(|_| format!("`{n}` is not a number"))?;
                if n == 0 {
                    return Err("word count must be at least 1".into());
                }
                mode = Mode::Words(n);
            }
            "-t" | "--time" => {
                let s = args.next().ok_or("-t needs a duration in seconds")?;
                let s: u32 = s.parse().map_err(|_| format!("`{s}` is not a number"))?;
                if s == 0 {
                    return Err("duration must be at least 1 second".into());
                }
                mode = Mode::Time(s);
            }
            other => return Err(format!("unknown option `{other}`")),
        }
    }
    Ok(Some(mode))
}

struct App {
    registry_state: RegistryState,
    seat_state: SeatState,
    output_state: OutputState,
    shm: Shm,
    pool: SlotPool,
    window: Window,
    qh: QueueHandle<App>,
    keyboard: Option<wl_keyboard::WlKeyboard>,
    pointer: Option<wl_pointer::WlPointer>,
    modifiers: Modifiers,
    loop_handle: LoopHandle<'static, App>,

    exit: bool,
    configured: bool,
    /// Logical size, as configured by the compositor.
    width: u32,
    height: u32,
    scale: i32,
    buffer: Option<Buffer>,

    fonts: Fonts,
    test: Test,
    view: View,

    dirty: bool,
    /// False while a frame callback is outstanding.
    frame_ready: bool,
    last_draw: Instant,
    /// When the last character was typed, for the caret hold.
    last_key: Option<Instant>,
    /// Pointer position in device pixels.
    pointer_pos: (f64, f64),
}

impl App {
    fn buffer_size(&self) -> (u32, u32) {
        (self.width * self.scale as u32, self.height * self.scale as u32)
    }

    /// Advance time-driven state. Returns how long to wait before the next tick.
    fn tick(&mut self) -> Duration {
        if self.test.tick() {
            self.view.reset_motion();
            self.dirty = true;
        }

        // The caret sits solid just after a keystroke, then resumes blinking.
        let blink = if self.test.phase == Phase::Done {
            false
        } else {
            match self.last_key {
                Some(t) if t.elapsed() < BLINK_HOLD => true,
                Some(t) => (t.elapsed().as_millis() % BLINK_PERIOD) * 2 < BLINK_PERIOD,
                None => true,
            }
        };
        if blink != self.view.blink_on {
            self.view.blink_on = blink;
            self.dirty = true;
        }

        // Timed mode shows a countdown, so redraw when the second changes.
        if let Mode::Time(_) = self.test.mode {
            if self.test.phase == Phase::Running {
                self.dirty = true;
            }
        }

        let (bw, bh) = self.buffer_size();
        let moving =
            render::animating(&self.test, &self.view, bw as f32, bh as f32, &mut self.fonts);
        if moving {
            self.dirty = true;
        }

        self.flush();
        if moving { TICK_ACTIVE } else { TICK_IDLE }
    }

    /// Draw if there is anything new and the compositor is ready for it.
    fn flush(&mut self) {
        if self.dirty && self.frame_ready && self.configured {
            self.draw();
        }
    }

    fn draw(&mut self) {
        let (bw, bh) = self.buffer_size();
        if bw == 0 || bh == 0 {
            return;
        }
        let stride = bw as i32 * 4;

        let now = Instant::now();
        let dt = now.duration_since(self.last_draw).as_secs_f32().min(0.1);
        self.last_draw = now;

        let App { pool, buffer, fonts, test, view, window, qh, scale, .. } = self;

        let buffer = buffer.get_or_insert_with(|| {
            pool.create_buffer(bw as i32, bh as i32, stride, wl_shm::Format::Argb8888)
                .expect("create buffer")
                .0
        });

        let canvas = match pool.canvas(buffer) {
            Some(canvas) => canvas,
            None => {
                // The compositor still holds the previous buffer, so take a
                // second one rather than stalling on it.
                let (second, canvas) = pool
                    .create_buffer(bw as i32, bh as i32, stride, wl_shm::Format::Argb8888)
                    .expect("create buffer");
                *buffer = second;
                canvas
            }
        };

        // Render straight into the shared buffer; no intermediate copy.
        if let Some(mut pm) = PixmapMut::from_bytes(canvas, bw, bh) {
            render::draw(&mut pm, fonts, test, view, dt, *scale as f32);
        }

        let surface = window.wl_surface();
        surface.damage_buffer(0, 0, bw as i32, bh as i32);
        surface.frame(qh, FrameCallbackData(surface.clone()));
        buffer.attach_to(surface).expect("buffer attach");
        window.commit();

        self.dirty = false;
        self.frame_ready = false;
    }

    fn restart(&mut self) {
        self.test.reset();
        self.view.reset_motion();
        self.view.blink_on = true;
        self.last_key = None;
        self.dirty = true;
    }

    fn on_key(&mut self, event: KeyEvent) {
        let ctrl = self.modifiers.ctrl;
        match event.keysym {
            Keysym::Escape => {
                self.exit = true;
                return;
            }
            Keysym::Tab => {
                self.restart();
                return;
            }
            Keysym::Return | Keysym::KP_Enter => {
                if self.test.phase == Phase::Done {
                    self.restart();
                }
                return;
            }
            Keysym::BackSpace => {
                if self.test.backspace(ctrl) {
                    self.last_key = Some(Instant::now());
                    self.view.blink_on = true;
                    self.dirty = true;
                }
                return;
            }
            Keysym::q | Keysym::w if ctrl => {
                self.exit = true;
                return;
            }
            _ => {}
        }

        if ctrl || self.modifiers.alt || self.modifiers.logo {
            return;
        }

        let Some(utf8) = event.utf8 else { return };
        for ch in utf8.chars() {
            // Reject control characters; everything printable is fair game.
            if ch.is_control() {
                continue;
            }
            if self.test.type_char(ch) {
                self.last_key = Some(Instant::now());
                self.view.blink_on = true;
                self.dirty = true;
            }
            if self.test.phase == Phase::Done {
                break;
            }
        }
    }
}

impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        new_factor: i32,
    ) {
        if new_factor != self.scale && new_factor > 0 {
            self.scale = new_factor;
            self.window.wl_surface().set_buffer_scale(new_factor);
            self.buffer = None;
            self.view.reset_motion();
            self.dirty = true;
            self.flush();
        }
    }

    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wl_output::Transform,
    ) {
    }

    fn frame(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &wl_surface::WlSurface, _: u32) {
        self.frame_ready = true;
        self.flush();
    }

    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
}

impl WindowHandler for App {
    fn request_close(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &Window) {
        self.exit = true;
    }

    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &Window,
        configure: WindowConfigure,
        _: u32,
    ) {
        let w = configure.new_size.0.map(|v| v.get()).unwrap_or(DEFAULT_SIZE.0);
        let h = configure.new_size.1.map(|v| v.get()).unwrap_or(DEFAULT_SIZE.1);
        if w != self.width || h != self.height {
            self.width = w;
            self.height = h;
            self.buffer = None;
            self.view.reset_motion();
        }
        self.configured = true;
        self.dirty = true;
        self.flush();
    }
}

impl SeatHandler for App {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }

    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}

    fn new_capability(
        &mut self,
        _: &Connection,
        qh: &QueueHandle<Self>,
        seat: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Keyboard && self.keyboard.is_none() {
            if let Ok(kb) = self.seat_state.get_keyboard_with_repeat(
                qh,
                &seat,
                None,
                self.loop_handle.clone(),
                Box::new(|app: &mut App, _, event| {
                    app.on_key(event);
                    app.flush();
                }),
            ) {
                self.keyboard = Some(kb);
            }
        }
        if capability == Capability::Pointer && self.pointer.is_none() {
            self.pointer = self.seat_state.get_pointer(qh, &seat).ok();
        }
    }

    fn remove_capability(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Keyboard {
            if let Some(kb) = self.keyboard.take() {
                kb.release();
            }
        }
        if capability == Capability::Pointer {
            if let Some(p) = self.pointer.take() {
                p.release();
            }
        }
    }

    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
}

impl KeyboardHandler for App {
    fn enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: &wl_surface::WlSurface,
        _: u32,
        _: &[u32],
        _: &[Keysym],
    ) {
    }

    fn leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: &wl_surface::WlSurface,
        _: u32,
    ) {
    }

    fn press_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        self.on_key(event);
        self.flush();
    }

    /// Repeats the compositor generates itself. Client-side repeat arrives
    /// through the callback given to `get_keyboard_with_repeat` instead; only
    /// one of the two paths is ever active for a given key.
    fn repeat_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        self.on_key(event);
        self.flush();
    }

    fn release_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        _: KeyEvent,
    ) {
    }

    fn update_modifiers(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        modifiers: Modifiers,
        _: RawModifiers,
        _: u32,
    ) {
        self.modifiers = modifiers;
    }
}

impl PointerHandler for App {
    fn pointer_frame(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_pointer::WlPointer,
        events: &[PointerEvent],
    ) {
        for event in events {
            if &event.surface != self.window.wl_surface() {
                continue;
            }
            let s = self.scale as f64;
            match event.kind {
                PointerEventKind::Leave { .. } => {
                    self.pointer_pos = (-1.0, -1.0);
                }
                PointerEventKind::Enter { .. } | PointerEventKind::Motion { .. } => {
                    self.pointer_pos = (event.position.0 * s, event.position.1 * s);
                }
                PointerEventKind::Release { button, .. } => {
                    // BTN_LEFT
                    if button == 0x110 {
                        let (x, y) = (self.pointer_pos.0 as f32, self.pointer_pos.1 as f32);
                        if self.view.close_rect.contains(x, y) {
                            self.exit = true;
                            return;
                        }
                        if self.view.continue_rect.contains(x, y) {
                            self.restart();
                        }
                    }
                }
                _ => {}
            }
        }

        let (x, y) = (self.pointer_pos.0 as f32, self.pointer_pos.1 as f32);
        let hc = self.view.continue_rect.contains(x, y);
        let hx = self.view.close_rect.contains(x, y);
        if hc != self.view.hover_continue || hx != self.view.hover_close {
            self.view.hover_continue = hc;
            self.view.hover_close = hx;
            self.dirty = true;
        }
        self.flush();
    }
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl ShmHandler for App {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

delegate_registry!(App);

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState, SeatState];
}

smithay_client_toolkit::delegate_dispatch2!(App);
