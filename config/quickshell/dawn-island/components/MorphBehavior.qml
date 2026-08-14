import QtQuick
import qs
import qs.theme

/*
 * The island's shape morph.
 *
 * A real spring rather than a fixed-duration curve, for one concrete reason:
 * states interrupt each other constantly (a volume keypress during a media
 * expansion, a notification mid-collapse). A spring carries its current
 * velocity into the new target, so an interrupted morph stays continuous
 * instead of visibly restarting. That continuity is most of what makes the
 * motion read as physical.
 *
 * Damping of 1.0 is critical damping — no overshoot at all — so setting
 * Config.useRealSpring to false simply stiffens this into a clean ease.
 */
Behavior {
    enabled: Config.animationsEnabled

    SpringAnimation {
        spring: Anim.springStiffness
        damping: Anim.useSpring ? Anim.springDamping : 1.0
        mass: Anim.springMass
        epsilon: Anim.springEpsilon
    }
}
